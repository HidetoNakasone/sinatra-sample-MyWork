
require "sinatra"
require "sinatra/reloader"

require "mysql2"
require 'mysql2-cs-bind'

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
  if session[:user_id].nil?
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

  @res = client.xquery("SELECT * FROM tweets ORDER BY id #{session[:user_order]} ;")
  if @res.size < 1
    @res_info = "No Data."
  else
    @res.each do |row|
      row['dateinfo-con'] = time_con(row['dateinfo'])
      if row['creater_id'] == session[:user_id]
        row['is_creater'] = true
      else
        row['is_creater'] = false
      end
    end
  end

  @pagename = "簡易掲示板"
  @user_name = session[:user_name]
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
    session[:user_id] = res['id']
    session[:user_name] = res['user_name']
    # 初期のorderは、asc設定。
    session[:user_order] = "ASC"
    page_message = "<p style='padding: 0 10px;'>Success.<br>適正ユーザーです<br>「データベースへアクセス開始...」</p>"
  else
    page_message = "<p style='padding: 0 10px; color: rgba(255, 253, 85, 1);'>Error.<br>不正アクセス<br>「システムとのリンクを構築できません」</p>"
  end
  session[:page_message] = page_message
  redirect '/'
end

# ====================

get '/logout' do
  session[:user_id] = nil
  session[:user_name] = nil
  session[:user_order] = nil
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

  client.xquery("INSERT INTO tweets VALUES (NULL, ?, ?, ?, ?, ?);", session[:user_id].to_s, session[:user_name].to_s, DateTime.now, Rack::Utils.escape_html(params[:msg]), up_img_name)
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
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>削除完了<br>「正常に削除処理を実行しました」</p>"

  redirect '/'
end

# ====================

post '/order_by' do
  if params['order'] == "asc"
    session[:user_order] = "ASC"
    temp = "古い順"
  elsif params['order'] == "desc"
    session[:user_order] = "DESC"
    temp = "新しい順"
  end
  session[:page_message] = "<p style='padding: 0 10px;'>Success.<br>ソート変更<br>「表示をを#{temp}に設定しました。」</p>"
  redirect '/'
end

# ====================
