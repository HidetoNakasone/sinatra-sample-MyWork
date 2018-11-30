
require "sinatra"
require "sinatra/reloader"

require "mysql2"
require 'mysql2-cs-bind'

require "pry"

enable :sessions

# ====================

client = Mysql2::Client.new(
  :host => "localhost",
  :username => "root",
  :password => "root",
  :database => "hepdev"
)

# ====================

def is_login
  if session[:loginuser_id].nil?
    redirect '/login'
  end
end

# ====================

def time_con(time_info)
  if time_info > Time.now - 60
    # 1分 以内
    "#{(Time.now - time_info).floor}秒前"
  elsif time_info > Time.now - (60*60)
    # 1時間 以内
    "#{((Time.now - time_info)/(60)).floor}分前"
  elsif time_info > Time.now - (24*60*60)
    # 24時間 以内
    "#{((Time.now - time_info)/(60*60)).floor}時間前"
  elsif time_info > Time.now - (30*24*60*60)
    # 1月 以内
    "#{((Time.now - time_info)/(24*60*60)).floor}日前"
  elsif time_info > Time.now - (365*24*60*60)
    # 1年 以内
    "#{((Time.now - time_info)/(30*24*60*60)).floor}ヶ月前"
  else
    # 1年 以上
    "#{((Time.now - time_info)/(365*24*60*60)).floor}年前"
  end
end

# ====================

get '/' do
  is_login()
  @page_message = session[:page_message]
  session[:page_message] = nil

  @res = client.xquery("SELECT * FROM tweets ORDER BY id #{session[:loginuser_order]} #{session[:loginuser_sort_option]};")

  if @res.size < 1
    @res_info = "No Data."
  else
    @res.each do |row|

      row['dateinfo-con'] = time_con(row['dateinfo'])

      # その投稿者がログインユーザーかどうかを記憶
      if row['creater_id'] == session[:loginuser_id]
        row['is_creater'] = true
      else
        row['is_creater'] = false
      end

      # その投稿のいいね数を取得し記憶
      row['likes_count'] = client.xquery("SELECT COUNT(*) FROM likes WHERE tweet_id = #{row['id']};").first['COUNT(*)']

      # その投稿をログインユーザーがいいねしているか記憶
      temp_is_like = client.xquery("SELECT COUNT(*) FROM likes WHERE user_id = #{session[:loginuser_id]} && tweet_id = #{row['id']};").first['COUNT(*)']
      if temp_is_like == 1
        row['loginuser_is_like'] = true
      else
        row['loginuser_is_like'] = false
      end

      # その投稿に対するコメントを、新しい配列として記憶させている。
      row['comments'] = []
      res_comments = client.xquery("SELECT * FROM comments WHERE tweet_id = ?", row['id'])
      res_comments.each do |row_comment|
        row['comments'].push(
          {"creater_name" => row_comment['creater_name'], "comment" => row_comment['comment']}
        )
      end

    end
    # binding.pry
  end

  @pagename = "ちょい掲示板"
  @loginuser_name = session[:loginuser_name]
  erb :top
end

# ====================

get '/login' do
  @page_message = session[:page_message]
  if session[:page_message].nil?
    @page_message = "<p style='padding: 0 10px; color: rgba(255, 253, 85, 1);'>Unknown Youser<br>未登録ユーザー<br>「ユーザー認証プロセスへ」</p>"
  end
  session[:page_message] = nil

  @res = client.xquery("SELECT * FROM tweets;")
  @pagename = "ログイン画面"
  erb :login
end

# ====================

post '/login' do
  res = client.xquery("SELECT * FROM users WHERE user_name = ? && user_pass = ?;", Rack::Utils.escape_html(params[:login_name]), Rack::Utils.escape_html(params[:login_pass])).first

  page_message = nil
  if res
    session[:loginuser_id] = res['id']
    session[:loginuser_name] = res['user_name']
    # 初期のorderは、asc設定。
    session[:loginuser_order] = "ASC"
    session[:loginuser_sort_option] = ""

    page_message = "<p style='padding: 0 10px;'>Success.<br>適正ユーザーです<br>「データベースへアクセス開始...」</p>"
  else
    page_message = "<p style='padding: 0 10px; color: rgba(255, 253, 85, 1);'>Error.<br>不正アクセス<br>「システムとのリンクを構築できません」</p>"
  end
  session[:page_message] = page_message
  redirect '/'
end

# ====================

get '/logout' do
  session[:loginuser_id] = nil
  session[:loginuser_name] = nil
  session[:loginuser_order] = nil
  session[:loginuser_sort_option] = nil
  session[:page_message] = nil
  redirect '/'
end

# ====================

get '/signup' do
  @page_message = "<p style='padding: 0 10px;'>Info.<br>新規アカウント画面<br>「名前とパスワードを入力する必要があります」</p>"
  @pagename = "新規登録"
  erb :signup
end

# ====================

post '/signup' do
  res = client.xquery("SELECT id FROM users WHERE user_name = ?;", Rack::Utils.escape_html(params[:signup_name])).first

  page_message = nil
  if res.nil?
    page_message = "<p style='padding: 0 10px;'>Success.<br>登録成功<br>「ユーザー認証を行う必要があります。」</p>"
    client.xquery("INSERT INTO users VALUES (NULL, ?, ?);", Rack::Utils.escape_html(params[:signup_name]), Rack::Utils.escape_html(params[:signup_pass]))
  else
    page_message = "<p style='padding: 0 10px; color: rgba(255, 253, 85, 1);'>Error.<br>エラー検知<br>「入力されたユーザーは既存しています」</p>"
  end
  session[:page_message] = page_message

  redirect '/'
end

# ====================

post '/save' do
  is_login()

  up_img_name = nil
  if params[:upimg].nil?
    up_img_name = nil
  else
    up_img_name = ((0..9).to_a + ("a".."z").to_a + ("A".."Z").to_a).sample(30).join

    file = params[:upimg][:tempfile]
    File.open("./public/upimgs/" + up_img_name + ".jpg", 'w') do |f|
      f.write(file.read)
    end
  end

  client.xquery("INSERT INTO tweets VALUES (NULL, ?, ?, ?, ?, ?);", session[:loginuser_id].to_s, session[:loginuser_name].to_s, DateTime.now, Rack::Utils.escape_html(params[:msg]), up_img_name)
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>追加完了<br>「データが正常に処理されました」</p>"

  redirect '/'
end

# ====================

delete '/tweet_delete' do
  # ファイル削除
  if params[:img_name] != ""
    FileUtils.rm("./public/upimgs/" + params[:img_name] + ".jpg")
  end
  client.xquery("DELETE FROM tweets WHERE id = ?;", params[:tweet_id])
  client.xquery("DELETE FROM likes WHERE tweet_id = ?;", params[:tweet_id])
  client.xquery("DELETE FROM comments WHERE tweet_id = ?;", params[:tweet_id])
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>削除完了<br>「正常に削除処理を実行しました」</p>"

  redirect '/'
end

# ====================

post '/sql_option' do

  if params[:order] == "asc"
    session[:loginuser_order] = "ASC"
    temp = "を古い順"
  elsif params[:order] == "desc"
    session[:loginuser_order] = "DESC"
    temp = "を新しい順"
  end

  if params[:sort_size] != nil && params[:sort_size] != "default"
    if params[:sort_size] == "all"
      session[:loginuser_sort_option] = ""
      temp = "数を全て"
    else
      session[:loginuser_sort_option] = "LIMIT #{params[:sort_size]}"
      temp = "数を#{params[:sort_size]}"
    end
  end

  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>ソート変更<br>「表示#{temp}に設定しました。」</p>"

  redirect '/'
end

# ====================

post '/likes' do
  client.xquery("INSERT INTO likes VALUES(NULL, ?, ?);", session[:loginuser_id], params[:tweet_id])
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>いいね追加<br>「追加処理が正常に行われました」</p>"
  redirect '/'
end

# ====================

delete '/likes' do
  client.xquery("DELETE FROM likes WHERE user_id = ? && tweet_id = ?;", session[:loginuser_id], params[:tweet_id])
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>いいね取り消し<br>「取り消し処理が正常に行われました」</p>"
  redirect '/'
end

# ====================

post '/comment' do
  # binding.pry
  client.xquery("INSERT INTO comments VALUES(NULL, ?, ?, ?, ?);", session[:loginuser_id], session[:loginuser_name], params[:tweet_id], Rack::Utils.escape_html(params[:add_comment]))
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>コメント追加<br>「追加処理が正常に行われました」</p>"
  redirect '/'
end

# ====================
