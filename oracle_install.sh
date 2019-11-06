#!/bin/bash
#Author: Musker.Chao
#oracle 12c
#local host ip
#address: https://github.com/spdir/oracle-single-install
# 国内仓库地址: https://gitee.com/spdir/oracle-single-install
HostIP=""
#oracle user password
OracleUserPasswd="oracle.com"
#default `systemOracle.com`
ORACLE_DB_PASSWD=""
#SID/SERVERNAME,default `oriedb`
SID=""
# Install single instance choose charset
# 1-AL32UTF8(default), 2-ZHS16GBK
# Currently only supports single instance, does not support pdb
SINGLE_CHARSET='1'
# Install instance
#0-no,1-singleInstance,2-cdb
IS_INSTANCE='1'
# Choose configure file path
# 0-remote(default)  1-local
Get_Config_Method="0"
#---------------------------------------------------------------------------------#
#Global environment variable
if [[ ${SID} == "" ]];then
  SID="oriedb"
fi
root_path=`pwd`
response='/home/oracle/response'
MemTotle=$(grep -r 'MemTotal' /proc/meminfo | awk -F ' ' '{print int($2/1024/1024+1)}')
ORACLE_HOME='/data/app/oracle/product/12.2.0/db_1'
con_name="
sqlplus / as sysdba<< EOF
show con_name;
exit;
EOF
"
web_plugin="
sqlplus / as sysdba<< EOF
exec dbms_xdb_config.sethttpport(1522);
exit;
EOF
"
cdb_sql="
sqlplus / as sysdba<< EOF
shutdown abort;
create spfile from pfile='"$ORACLE_HOME/dbs/initcdb.ora"';
startup nomount;
CREATE DATABASE ${SID}
USER SYS IDENTIFIED BY pass
USER SYSTEM IDENTIFIED BY pass
LOGFILE GROUP 1 ('"/data/app/oracle/oradata/${SID}/redo01a.log"','"/data/app/oracle/oradata/${SID}/redo01b.log"')
SIZE 100M BLOCKSIZE 512,
GROUP 2 ('"/data/app/oracle/oradata/${SID}/redo02a.log"','"/data/app/oracle/oradata/${SID}/redo02b.log"')
SIZE 100M BLOCKSIZE 512
MAXLOGHISTORY 1
MAXLOGFILES 16
MAXLOGMEMBERS 3
MAXDATAFILES 1024
CHARACTER SET AL32UTF8
NATIONAL CHARACTER SET AL16UTF16
EXTENT MANAGEMENT LOCAL
DATAFILE '"/data/app/oracle/oradata/${SID}/system01.dbf"' SIZE 700M
SYSAUX DATAFILE '"/data/app/oracle/oradata/${SID}/sysaux01.dbf"' SIZE 550M
DEFAULT TABLESPACE deftbs
DATAFILE '"/data/app/oracle/oradata/${SID}/deftbs01.dbf"' SIZE 500M
DEFAULT TEMPORARY TABLESPACE tempts1
TEMPFILE '"/data/app/oracle/oradata/${SID}/temp01.dbf"' SIZE 20M
UNDO TABLESPACE undotbs1
DATAFILE '"/data/app/oracle/oradata/${SID}/undotbs01.dbf"' SIZE 200M
ENABLE PLUGGABLE DATABASE
SEED
FILE_NAME_CONVERT = ('"/data/app/oracle/oradata/${SID}/"',
'/data/app/oracle/oradata/pdbseed/')
SYSTEM DATAFILES SIZE 125M AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED
SYSAUX DATAFILES SIZE 100M
USER_DATA TABLESPACE usertbs
DATAFILE '/data/app/oracle/oradata/pdbseed/usertbs01.dbf' SIZE 200M;
exit
EOF
"

#Judgment parameter
function j_para() {
  #判断必要参数是否存在
  if [[ ${HostIP} == '' ]];then
    echo -e "\033[34mInstallNotice >>\033[0m \033[31mPlease config HostIP\033[0m"
    exit
  fi
  #判断数据库包文件是否存在
  if [ ! -f "/tmp/linuxx64_12201_database.zip" ]; then
    echo -e "\033[34mInstallNotice >>\033[0m \033[31mlinuxx64_12201_database.zip not found\033[0m"
    exit
  fi
  if [[ ${Get_Config_Method} == "1" ]]; then
    if [[ ${IS_INSTANCE} == '1' ]]; then
      if [[ ! -f ${root_path}/conf/db_install.rsp || ! -f ${root_path}/conf/dbca_single.rsp ]]; then
        echo -e "\033[34mInstallNotice >>\033[0m \033[31m ./conf/db_install.rsp or ./conf/dbca_single.rsp file not found\033[0m"
        exit
      fi
    elif [[ ${IS_INSTANCE} == '2' ]]; then
      if [[ ! -f ${root_path}/conf/initcdb.ora ]]; then
        echo -e "\033[34mInstallNotice >>\033[0m \033[31m ./conf/initcdb.ora file not found\033[0m"
        exit
      fi
    else
      if [[ ! -f ${root_path}/conf/db_install.rsp ]]; then
        echo -e "\033[34mInstallNotice >>\033[0m \033[31m ./conf/db_install.rsp file not found\033[0m"
        exit
      fi
    fi
  fi
}

#install package
function install_package() {
  yum install -y binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33.i686 glibc glibc.i686 \
  glibc-devel glibc-devel.i686 ksh libaio libaio.i686 libaio-devel libaio-devel.i686 libX11 libX11.i686 \
  libXau libXau.i686 libXi libXi.i686 libXtst libXtst.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 \
  libstdc++-devel libstdc++-devel.i686 libxcb libxcb.i686 make nfs-utils net-tools smartmontools sysstat \
  unixODBC unixODBC-devel gcc gcc-c++ libXext libXext.i686 zlib-devel zlib-devel.i686 unzip wget vim epel-release
}

#base_config
function base_config() {
  echo "${HostIP}  DB" >> /etc/hosts
  #close selinux
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  setenforce 0
  #close firewalld
  systemctl stop firewalld && systemctl disable firewalld
  #add user and group
  groupadd oinstall && groupadd dba && groupadd oper && useradd -g oinstall -G dba,oper oracle \
  && echo "$OracleUserPasswd" | passwd oracle --stdin
  #mkdir oracle need directory
  orcl_home='/data/app'
  mkdir -p ${orcl_home}/oracle/product/12.2.0/db_1 && chmod -R 775 ${orcl_home}/oracle \
  && chown -R oracle:oinstall ${orcl_home}
  #modify some file
  echo 'fs.file-max = 6815744
  kernel.sem = 250 32000 100 128
  kernel.shmmni = 4096
  kernel.shmall = 1073741824
  kernel.shmmax = 4398046511104
  kernel.panic_on_oops = 1
  net.core.rmem_default = 262144
  net.core.rmem_max = 4194304
  net.core.wmem_default = 262144
  net.core.wmem_max = 1048576
  net.ipv4.conf.all.rp_filter = 2
  net.ipv4.conf.default.rp_filter = 2
  fs.aio-max-nr = 1048576
  net.ipv4.ip_local_port_range = 9000 65500
  ' >> /etc/sysctl.conf  && sysctl -p
  echo 'oracle   soft   nofile    1024
  oracle   hard   nofile    65536
  oracle   soft   nproc    16384
  oracle   hard   nproc    16384
  oracle   soft   stack    10240
  oracle   hard   stack    32768
  oracle   hard   memlock    134217728
  oracle   soft   memlock    134217728
  ' >> /etc/security/limits.d/20-nproc.conf
  echo 'session  required   /lib64/security/pam_limits.so
  session  required   pam_limits.so
  ' >> /etc/pam.d/login
  echo 'if [ $USER = "oracle" ]; then
    if [ $SHELL = "/bin/ksh" ]; then
     ulimit -p 16384
     ulimit -n 65536
    else
     ulimit -u 16384 -n 65536
    fi
  fi
  ' >> /etc/profile
  #add oracle environmental variable
  echo '# Oracle Settings
  export TMP=/tmp
  export TMPDIR=$TMP
  export ORACLE_HOSTNAME=DB
  export ORACLE_UNQNAME=oriedb
  export ORACLE_BASE=/data/app/oracle
  export ORACLE_HOME=$ORACLE_BASE/product/12.2.0/db_1
  export ORACLE_SID=oriedb
  export PATH=/usr/sbin:$PATH
  export PATH=$ORACLE_HOME/bin:$PATH
  export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
  export CLASSPATH=$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
  ' > /tmp/oracleInstallTmp.txt

  if [[ ${SID} != 'oriedb' ]];then
    sed -i "s/oriedb/${SID}/g" /tmp/oracleInstallTmp.txt
  fi
  cat /tmp/oracleInstallTmp.txt >> /home/oracle/.bash_profile && bash /home/oracle/.bash_profile
  rm -rf /tmp/oracleInstallTmp.txt
}

#option oracle file
function oracle_file() {
  #Decompression package
  unzip /tmp/linuxx64_12201_database.zip -d /tmp
  chown -R oracle:oinstall /tmp/database
  #get install config file
  mkdir -p ${response} && cd ${response}
  # delete old config
  rm -rf {db_install.rsp,dbca_single.rsp}
  # get config method
  if [[ ${Get_Config_Method} == "1" ]]; then
    cp ${root_path}/conf/db_install.rsp .
    cp ${root_path}/conf/dbca_single.rsp .
  else
    wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/conf/db_install.rsp
    wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/conf/dbca_single.rsp
  fi
  #modify config file
  if [[ ${ORACLE_DB_PASSWD} != "" ]];then
    sed -i "s/systemOracle.com/${ORACLE_DB_PASSWD}/g" dbca_single.rsp
  fi
  #option memory gt 4G
  if [[ ${MemTotle} -gt 4 ]];then
    sed -i 's/automaticMemoryManagement=true/automaticMemoryManagement=false/g' \
     /home/oracle/response/dbca_single.rsp
  fi
  #modify config file `SID`
  if [[ ${SID} != 'oriedb' ]];then
     sed -i "s/oriedb/${SID}/g" db_install.rsp
     sed -i "s/oriedb/${SID}/g" dbca_single.rsp
  fi
  #modify oracle single instance default charset
  if [[ ${SINGLE_CHARSET} == '2' ]]; then
     sed -i 's/characterSet=AL32UTF8/characterSet=ZHS16GBK/g' dbca_single.rsp
  fi
  #copy config file to oracle home
  cp /tmp/database/response/netca.rsp ${response}/netca.rsp
  chown -R oracle:oinstall ${response}
}

#start install oracle software and start listen
function install_oracle() {
  #start install oracle
  oracle_out='/tmp/oracle.out'
  su - oracle -c "/tmp/database/runInstaller -force -silent -noconfig \
  -responseFile ${response}/db_install.rsp -ignorePrereq" 1> ${oracle_out}
  echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install starting \033[05m...\033[0m"
  while true; do
    grep '[FATAL] [INS-10101]' ${oracle_out} &> /dev/null
    if [[ $? == 0 ]];then
      echo -e "\033[34mInstallNotice >>\033[0m \033[31moracle start install has [ERROR]\033[0m"
      cat ${oracle_out}
      exit
    fi
    cat /tmp/oracle.out  | grep sh
    if [[ $? == 0 ]];then
      `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | head -1`
	  if [[ $? == 0 ]]; then
        echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript 1 run ok\033[0m"
	  else
	    echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript 1 run faild\033[0m"
	  fi
      `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | tail -1`
	  if [[ $? == 0 ]];then
        echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript 2 run ok\033[0m"
	  else
	    echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript 2 run faild\033[0m"
	  fi
      #start listen
      echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle start listen \033[05m...\033[0m"
      su - oracle -c "netca /silent /responsefile ${response}/netca.rsp"
      netstat -anptu | grep 1521
      if [[ $? == 0 ]]; then
        echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle run listen\033[0m"
        break
      else
        echo -e "\033[34mInstallNotice >>\033[0m \033[31mOracle no run listen\033[0m"
        exit
      fi
    fi
  done
}

#install oracle single instance
function single_instance() {
  echo -e "\033[34mInstallNotice >>\033[0m \033[32mStart install single instance \033[05m...\033[0m"
  #此安装过程会输入三次密码，超级管理员，管理员，库(这些密码也可以在配置文件中写)
  su - oracle -c "dbca -silent -createDatabase  -responseFile ${response}/dbca_single.rsp"
  su - oracle -c "mkdir -p /data/app/oracle/oradata/${SID}/"
  su - oracle -c "${con_name}" > /tmp/oracle.out1
  su - oracle -c "${web_plugin}"
  grep "${SID}" /tmp/oracle.out1
  if [[ $? == 0 ]];then
    echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle and instances install successful\033[0m"
    echo -e "\033[34mYou can visit (http://${HostIP}:1522/em) for web management.\033[0m"
  else
    echo -e "\033[34mInstallNotice >>\033[0m \033[31mOracle install successful,but instances init faild\033[0m"
  fi
  rm -rf /tmp/oracle.out1
  exit
}

#install oracle cdb instance
function cdb_pdb() {
  echo -e "\033[34mInstallNotice >>\033[0m \033[32mStart install CDB \033[05m...\033[0m"
  INIT_CDB_FILE="/data/app/oracle/product/12.2.0/db_1/dbs/initcdb.ora"
  rm -rf ${INIT_CDB_FILE}
  if [[ ${Get_Config_Method} == "1" ]]; then
    cp ${root_path}/conf/initcdb.ora ${INIT_CDB_FILE}
  else
      wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/conf/initcdb.ora -O ${INIT_CDB_FILE}
  fi
  
  if [[ ${SID} != 'oriedb' ]];then
    sed -i "s/oriedb/${SID}/g" ${INIT_CDB_FILE}
  fi
  if [[ ${MemTotle} -gt 4 ]];then
    cdb_mem=`expr ${MemTotle} / 3`
    proc=`expr 150 \* ${cdb_mem}`
    sed -i "s/memory_target=1G/memory_target=${cdb_mem}G/g" ${INIT_CDB_FILE}
    sed -i "s/processes = 150/processes = ${proc}/g" ${INIT_CDB_FILE}
  fi
  chown -R oracle:oinstall ${INIT_CDB_FILE}
  su - oracle -c "
  mkdir -p /data/app/oracle/oradata/${SID}
  mkdir -p /data/app/oracle/oradata/pdbseed
  mkdir -p /data/app/oracle/admin/${SID}/adump
  mkdir -p /data/app/oracle/fast_recovery_area
  "
  echo ${cdb_sql}
  su - oracle -c "${cdb_sql}"
  su - oracle -c "sed -i '35s/util/Util/g' /data/app/oracle/product/12.2.0/db_1/rdbms/admin/catcdb.pl"
  echo -e '\033[42;31mFollow the steps to run the following commands\033[0m
  \033[34m1. $ \033[32msu - oracle\033[0m\033[0m
  \033[34m2. $ \033[32mcd /data/app/oracle/product/12.2.0/db_1/perl/lib/5.22.0/x86_64-linux-thread-multi/Hash/\033[0m\033[0m
  \033[34m3. $ \033[32mexport PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$ORACLE_HOME/perl/bin:$ORACLE_HOME/jdk/bin:$PATH\033[0m\033[0m
  \033[34m4. $ \033[32msqlplus / as sysdba\033[0m\033[0m
  \033[34m5. SQL > \033[32m@?/rdbms/admin/catcdb.sql\033[0m\033[0m
  \033[34m   Enter value for 1: \033[32m/data/app/oracle/product/12.2.0/db_1/rdbms/admin\033[0m\033[0m
  \033[34m   Enter value for 2: \033[32m/data/app/oracle/product/12.2.0/db_1/rdbms/admin/catcdb.pl\033[0m\033[0m
  \033[34m   Enter new password for SYS: \033[32msys user password\033[0m\033[0m
  \033[34m   Enter new password for SYSTEM: \033[32msystem user password\033[0m\033[0m
  \033[34m   Enter temporary tablespace name: \033[32mtablespace name\033[0m\033[0m
  \033[34m6. SQL > \033[32mshow con_name;\033[0m\033[0m
  \033[34m7. SQL > \033[32mshow pdbs;\033[0m\033[0m'
  echo -e '\033[33mThe initialization process is relatively long. Please wait patiently.\033[0m'
  echo -e '\033[33mCDB use reference: \033[34mhttps://www.cnblogs.com/zhichaoma/p/9328765.html\033[0m'
  exit
}

#install oracle instance
function oracle_instance() {
  #安装Oracle实例
  if [[ ${IS_INSTANCE} == '1' ]]; then  #install single instance
    single_instance
  elif [[ ${IS_INSTANCE} == '2' ]];then   #install oracle cdb
    cdb_pdb
  else  # not install instance
    echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle install successful, but there are no instances of installation\033[0m"
    exit
  fi
}

function main() {
  j_para && \
  install_package && \
  base_config && \
  oracle_file && \
  install_oracle && \
  oracle_instance
}

#run script
main
