### oracle 12C 自动化静默安装脚本
> Author QQ: 1152490990<br>
>Author email: aery_mzc9123@163.com

#### 下载安装脚本
```bash
wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/oracle_install.sh
```

#### 脚本使用安装前配置
1. 安装前请将Oracle 12C安装包放置在`/tmp`目录下
2. 系统需要具备512MB的交换分区
3. 并配置好以下信息
  - 本机IP地址 `HostIP`
  - Oracle用户密码 `OracleUserPasswd` 默认为`oracle.com`
  - Oracle数据库管理员密码 `ORACLE_DB_PASSWD` 默认为 `systemOracle.com`
  - Oracle SID/ServerName `SID` 默认为 `oriedb`

#### Oracle 12C安装包下载
[百度网盘](https://pan.baidu.com/s/1YvgmT0_Pm7y4O2XOxlFc3g)

#### 支持系统
<font color=red size=14>注: 作者已在CentOS 7进行测试，无问题。如果有其他什么问题，或者您在其他系统测试通过，可以联系作者</font>
- CentOS 7 64/32

