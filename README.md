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

### ローカル環境でLine APIを試す

1) ngrokでコマンドで外部に公開するURLを生成できる(ngrokをローカルにインストールしている前提)<br>
`ngrok http <docker ip>:3000`

2) jqを公式サイトからDLし、環境に応じてセットアップする<br>
https://stedolan.github.io/jq/<br>

3) jqコマンドでngrokのipを取得する<br>
`curl -s localhost:4040/api/tunnels | jq-win64.exe -r ".tunnels[].public_url"`

### 補足

環境変数は.envファイルで設定する。
注意点として、.envに「#コメント」などを記述すると、環境変数が読み込めなくなるので注意。


### 注意点

Windows環境だと改行設定でdocker-compose webコンテナが立ち上がらない可能性がある。<br>
下記記事を参考に設定を見直すことをおススメします。<br>
https://qiita.com/okazy/items/8ce003fbb54e798b4af7