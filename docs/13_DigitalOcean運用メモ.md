# DigitalOcean運用メモ

作成日: 2026-07-04

## 結論

RoverWebapp / WebODM 用のDigitalOceanサーバーは、常時使わないなら、使わない期間はDropletを停止したまま残すのではなく、Snapshotまたは外部バックアップを取ってDropletを削除する運用で費用を抑える。

停止だけではDropletの課金は基本的に止まらない。計算資源とディスクを保持している扱いになるため、長期間使わない場合はSnapshot化してDropletを削除する。

## 現在確認できている状況

Gmail上のDigitalOcean通知と請求メールから確認した内容:

| 項目 | 内容 |
| --- | --- |
| 対象アカウント | My Team |
| GitHub Student Packクレジット残高 | USD 115.70 |
| クレジット失効日 | 2026-07-31 |
| 2026-04使用料 | USD 12.00 |
| 2026-05使用料 | USD 12.00 |
| 2026-06使用料 | USD 12.00 |
| 2026-04から2026-06の実請求 | クレジット適用によりUSD 0.00 |

2026-07-31以降、稼働中の有料リソースは通常課金になる。DigitalOceanからの通知では、未使用クレジットは持ち越し・移転できない。

## 費用感

2026-07-04時点の公式価格確認:

| 運用 | 概算 |
| --- | --- |
| 現在相当の2GB / 1vCPU / 50GB Dropletを稼働 | USD 12.00 / 月 |
| 50GB相当のDroplet Snapshotだけ保存 | 最大で概算USD 3.00 / 月程度 |

根拠:

- DigitalOcean Basic Droplet 2GB / 1vCPU / 50GB: USD 12.00 / 月
- Droplet Snapshot: USD 0.06 / GB / 月

Snapshot料金は保存されるイメージサイズで変わる。実際の月額はDigitalOceanのBilling画面で確認する。

## 運用パターン

### A. しばらく使う予定がある

Dropletを残してそのまま運用する。月額USD 12程度なら、移行や復元作業の手間より安い場合がある。

必ず行うこと:

- Billing alertをUSD 15またはUSD 20程度で設定する
- 不要な追加リソースがないか確認する
- Docker構成と永続データの場所を記録する

### B. 数週間から数か月使わない

Snapshotを作成し、復元確認後にDropletを削除する。

手順:

1. サーバーにSSHする。
2. Dockerとデータ配置を確認する。
3. 必要なアプリ内バックアップを取る。
4. DigitalOcean Control PanelでDroplet Snapshotを作成する。
5. Snapshotから別Dropletを作って復元できるか確認する。
6. 復元確認後、元Dropletを削除する。
7. 使わないReserved IP、Volume、Snapshotが残っていないかBillingで確認する。

### C. 当面使う予定がない

Snapshotだけでなく、必要データをローカルや別ストレージへ退避し、DigitalOcean側の有料リソースをすべて削除する。

この場合は復元に時間がかかるが、月額費用は最小化できる。

## 作業前チェック

サーバー上で実行する確認コマンド:

```bash
docker ps
docker compose ls
docker volume ls
docker images
du -sh /var/lib/docker
df -h
```

プロジェクト配置の確認例:

```bash
find /root /home /opt -maxdepth 3 -name "docker-compose.yml" 2>/dev/null
find /root /home /opt -maxdepth 3 -name ".env" 2>/dev/null
```

RoverWebappのパスワード確認:

```bash
docker ps
docker exec -it rover-gcs-prod sh -c 'find / -name password.txt 2>/dev/null -print -exec cat {} \;'
```

`password.txt`が無い場合、RoverWebapp実装上のデフォルトは`password`。

## バックアップ対象

最低限残すもの:

- `docker-compose.yml`
- `.env`
- Caddy / Nginx設定
- RoverWebappのリポジトリ状態、ブランチ、コミット
- WebODMのデータとDB
- Docker volume一覧
- Tailscale名、Tailscale IP
- Public IPv4
- DNS設定
- ログイン方法、SSH鍵、rootパスワード再設定手順

Snapshotを使う場合でも、`docker-compose.yml`や`.env`などの構成情報はテキストで別保存しておく。Snapshotだけに依存すると、復元後に何が動いていたか分かりにくい。

## 削除前チェック

Droplet削除前に確認する:

- Snapshot作成が完了している
- Snapshotから起動したDropletでSSHできる
- `docker ps`で必要コンテナが起動する
- RoverWebappへブラウザからログインできる
- WebODMなど他サービスのログインとデータが見える
- Tailscaleが再ログインまたは復帰できる
- DNSやIP変更が必要なサービスを把握している

確認できるまで元Dropletは削除しない。

## 復元時の注意

SnapshotからDropletを復元すると、Public IPv4は変わる可能性がある。次を確認する。

- DNSのAレコード
- Caddy / Nginxの証明書更新
- Tailscaleのデバイス名とログイン状態
- Rpanion / MAVLink Router側の接続先IP
- rover-gcsの配信URL、VDO.Ninja関連URL

Rover側がDigitalOceanサーバーのTailscale IPや名前を使っている場合は、復元後に`tailscale status`で到達性を確認する。

## 2026-07中の推奨アクション

1. 2026-07-20頃までにサーバー内のDocker構成とデータ配置を棚卸しする。
2. 2026-07-25頃までにSnapshotを作成する。
3. Snapshotから一度復元テストする。
4. 継続利用するならBilling alertを設定してUSD 12/月運用にする。
5. 利用しないなら2026-07-31前にDropletを削除する。

## 判断基準

| 状況 | 判断 |
| --- | --- |
| 月1回以上使う | Droplet継続でもよい |
| 数か月使わない | Snapshot化してDroplet削除 |
| 再構築してもよい | 構成ファイルとデータだけ保存してDigitalOcean側を削除 |
| 実演や外部共有で急に使う | Droplet継続または復元手順を事前に確認 |

現在の月額がUSD 12程度なので、短期間の休止では作業コストのほうが高い場合がある。1か月以上使わないならSnapshot化、数日から2週間程度なら継続でもよい。

