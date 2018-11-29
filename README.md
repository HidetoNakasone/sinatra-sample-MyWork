
データベース用意

CREATE DATABASE hepdev;

CREATE TABLE users (
  id int(11) auto_increment,
  user_name varchar(256),
  user_pass varchar(256),
  primary key(id)
);

CREATE TABLE tweets (
  id int(11) auto_increment,
  creater_id int(11),
  creater_name varchar(256),
  dateinfo DATETIME NULL,
  msg varchar(8000),
  img_name varchar(50),
  primary key(id)
);

CREATE TABLE likes (
  id int(11) auto_increment,
  user_id int(11),
  tweet_id int(11),
  primary key(id)
);

※sqlへアクセスするユーザーとパスワードを、app.rbのclientクラスで指定してください。
私の場合、rootユーザーのrootというパスワードにてアクセスしています。

![参考画像_1](https://raw.githubusercontent.com/HidetoNakasone/sinatra-sample-MyWork/master/README_imgs/01.png)

![参考画像_2](https://raw.githubusercontent.com/HidetoNakasone/sinatra-sample-MyWork/master/README_imgs/02.png)
