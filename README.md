### oracle 12C 自动化静默安装脚本

#### 下载安装脚本
```bash
wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/oracle_install.sh && \ 
chmod +x oracle_install.sh
```

#### 脚本使用安装前配置
> root用户执行(尽量系统为纯净环境)
1. 安装前请将Oracle 12C安装包放置在`/tmp`目录下
2. 系统需要具备512MB的交换分区
3. 系统可连通外网
4. 并配置以下信息
  - 本机IP地址 `HostIP`
  - Oracle用户密码 `OracleUserPasswd` 默认为`oracle.com`
  - Oracle数据库管理员密码 `ORACLE_DB_PASSWD` 默认为 `systemOracle.com`
  - Oracle SID/ServerName `SID` 默认为 `oriedb`
  - 是否安装实例 `IS_INSTANCE`
    - 0-不安装实例
    - 1-安装单实例
    - 2-安装cdb : 因为CDB在初始化过程中需要输入参数，需要手动初始化,具体步骤会在最后进行提示
  - 设置单实例默认字符编码`SINGLE_CHARSET`
    - 1-`AL32UTF8` 默认
    - 2-`ZHS16GBK`
  - 选择配置静默安装配置文件的获取方式`Get_Config_Method`
    - 0-远程(默认)
    - 2-本地获取(脚本执行根目录下需要有`conf`目录存放配置文件)
      - `db_install.rsp`  数据库安装配置文件
      - `dbca_single.rsp`  数据库单实例初始化配置文件
      - `initcdb.ora`  CDB初始化配置文件

#### Oracle 12C安装包下载
[百度网盘](https://pan.baidu.com/s/1YvgmT0_Pm7y4O2XOxlFc3g)

#### 支持系统
<font color=red size=2>注: 脚本已在CentOS 7.x进行测试。如果有其他什么问题，请提交 `issues`反馈</font> 
- CentOS 7 64/32


>注意: 在初始化cdb过程中如果出现 `No options to container mapping specified, no options will be installed in any containers` 信息不是报错，因为cdb初始化时间比较长，可以通过查看以上提示下给出的日志路径查看初始化情况
