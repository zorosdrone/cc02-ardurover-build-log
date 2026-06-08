> 元ファイル: `C:\Users\ta1na\source\rover-gcs\docs\memo.txt`
> 取得日: 2026-06-08
> 種別: 記録
> 備考: `rover-gcs` は変更せず、このリポジトリへ参考資料として取り込んだコピーです。
コマンドメモ

■MavProxy 
link add 0.0.0.0:14551
link remove 1

Webserverにテレメトリを送りたいとき
output add udp:webserver:14552
■ログ

#3．起動後コマンド
#  WebotsモードではMAVLinkのリンク設定を手動で行う必要があります
#  以下のコマンドをMAVProxyコンソールで実行してください
#   link add 0.0.0.0:14551
#   link list
#   link remove 1
#  Webapps GCSへの転送設定（必要に応じて）
#   output add udp:webserver:14552
#   output list
#   output remove 1



