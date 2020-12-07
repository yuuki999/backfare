# README

MarkDown記法: https://qiita.com/tbpgr/items/989c6badefff69377da7

* Ruby version<br>
2.6.6

* Rails version<br>
6.0.2

### セットアップ

1) リポジトリのクローン<br>
`git clone git@github.com:yuuki999/transportation_expense_settlement.git`

2) 1)でクローンしたディレクトリで下記コマンド<br>
`docker-compose up -d`

3) webコンテナでDBの初期セットアップ<br>
`docker-compose exec web bash`<br>
`rake db:create`<br>
`rake db:migrate`<br>


### 注意点

Windows環境だと改行設定でdocker-compose webコンテナが立ち上がらない可能性がある。<br>
下記記事を参考に設定を見直すことをおススメします。<br>
https://qiita.com/okazy/items/8ce003fbb54e798b4af7