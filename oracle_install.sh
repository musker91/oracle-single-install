#!/bin/bash
#Author: Musker.Chao
#oracle 12c
#local host ip
#address: https://github.com/spdir/oracle-single-install
HostIP=""
#oracle user password
OracleUserPasswd="oracle.com"
#default `systemOracle.com`
ORACLE_DB_PASSWD=""
#SID/SERVERNAME,default `oriedb`
SID=""
#install instance
#1-yes 0-no
IS_INSTANCE='1'
#---------------------------------------------------------------------------------#
#判断必要参数是否存在
if [[ ${HostIP} == '' ]];then
  echo -e "\033[34mInstallNotice >>\033[0m \033[05;31mPlease config HostIP\033[0m"
  exit
fi
#判断数据库包文件是否存在
if [ ! -f "/tmp/linuxx64_12201_database.zip" ]; then
  echo -e "\033[34mInstallNotice >>\033[0m \033[05;31mlinuxx64_12201_database.zip not found\033[0m"
  exit
fi
#Installation dependency package
yum install -y binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33.i686 glibc glibc.i686 \
glibc-devel glibc-devel.i686 ksh libaio libaio.i686 libaio-devel libaio-devel.i686 libX11 libX11.i686 \
libXau libXau.i686 libXi libXi.i686 libXtst libXtst.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 \
libstdc++-devel libstdc++-devel.i686 libxcb libxcb.i686 make nfs-utils net-tools smartmontools sysstat \
unixODBC unixODBC-devel gcc gcc-c++ libXext libXext.i686 zlib-devel zlib-devel.i686 unzip wget vim epel-release
#config hosts
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
oracle_home='/data/app'
mkdir -p ${oracle_home}/oracle/product/12.2.0/db_1 && chmod -R 775 ${oracle_home}/oracle \
&& chown -R oracle:oinstall ${oracle_home}
#modify some file
echo "fs.file-max = 6815744
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
" >> /etc/sysctl.conf  && sysctl -p
echo "oracle   soft   nofile    1024
oracle   hard   nofile    65536
oracle   soft   nproc    16384
oracle   hard   nproc    16384
oracle   soft   stack    10240
oracle   hard   stack    32768
oracle   hard   memlock    134217728
oracle   soft   memlock    134217728
" >> /etc/security/limits.d/20-nproc.conf
echo "session  required   /lib64/security/pam_limits.so
session  required   pam_limits.so
" >> /etc/pam.d/login
echo "if [ $USER = "oracle" ]; then
  if [ $SHELL = "/bin/ksh" ]; then
   ulimit -p 16384
   ulimit -n 65536
  else
   ulimit -u 16384 -n 65536
  fi
fi
" >> /etc/profile
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
if [[ ${SID} == "" ]];then
  SID="oriedb"
else
  sed -i "s/oriedb/${SID}/g" /tmp/oracleInstallTmp.txt
fi
cat /tmp/oracleInstallTmp.txt >> /home/oracle/.bash_profile && bash /home/oracle/.bash_profile
rm -rf /tmp/oracleInstallTmp.txt
#Decompression package
unzip /tmp/linuxx64_12201_database.zip -d /tmp
chown -R oracle:oinstall /tmp/database
#get install config file
response='/home/oracle/response'
mkdir ${response} && cd ${response}
wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/conf/db_install.rsp
wget https://raw.githubusercontent.com/spdir/oracle-single-install/master/conf/dbca_single.rsp
#modify config file
if [[ ${ORACLE_DB_PASSWD} != "" ]];then
  sed -i "s/systemOracle.com/${ORACLE_DB_PASSWD}/g" dbca_single.rsp
fi
#option memory gt 4G
MemTotle=`awk '($1 == "MemTotal:"){print $2/1048576}' /proc/meminfo`
if [[ ${MemTotle} > 4 ]];then
  sed -i "s/automaticMemoryManagement=true/automaticMemoryManagement=false/g" \
   /home/oracle/response/dbca_single.rsp
fi
#modify config file `SID`
if [[ ${SID} != 'oriedb' ]];then
   sed -i "s/oriedb/${SID}/g" db_install.rsp
   sed -i "s/oriedb/${SID}/g" dbca_single.rsp
fi
#copy config file to oracle home
cp /tmp/database/response/netca.rsp ${response}/netca.rsp
chown -R oracle:oinstall /home/oracle/response
#start install oracle
oracle_out='/tmp/oracle.out'
su - oracle -c "/tmp/database/runInstaller -force -silent -noconfig \
-responseFile ${response}/db_install.rsp -ignorePrereq" 1> ${oracle_out}
sleep 60
grep '[FATAL] [INS-10101]' ${oracle_out}
if [[ $? == 0 ]];then
  echo -e "\033[34mInstallNotice >>\033[0m \033[05;31moracle start install has [ERROR]\033[0m"
  cat ${oracle_out}
  exit
else
  echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle starting\033[0m"
fi
con_name="
sqlplus / as sysdba<< EOF
show con_name;
exit;
EOF
"
while true; do
   cat /tmp/oracle.out  | grep sh
   if [ $? == 0 ];then
     `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | head -1` && \
	  echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript 1 run ok\033[0m"
     `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | tail -1` && \
	  echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript 2 run ok\033[0m"
      su - oracle -c "netca /silent /responsefile ${response}/netca.rsp"
      netstat -anptu | grep 1521
	  if [ $? != 0 ]; then
	    echo -e "\033[34mInstallNotice >>\033[0m \033[05;31mOracle no run listen\033[0m"
	    exit
	  else
	    echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle run listen\033[0m"
      fi
      if [[ ${IS_INSTANCE} == '1' ]]; then  #install single instance
        #此安装过程会输入三次密码，超级管理员，管理员，库(这些密码也可以在配置文件中写)
        su - oracle -c "dbca -silent -createDatabase  -responseFile ${response}/dbca_single.rsp"
        su - oracle -c "mkdir -p /data/app/oracle/oradata/${SID}/"
        su - oracle -c "${con_name}" > /tmp/oracle.out1
        grep ${SID} /tmp/oracle.out1
        if [[ $? == 0 ]];then
          echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle and instances install successful\033[0m"
        else
          echo -e "\033[34mInstallNotice >>\033[0m \033[05;31mOracle install successful,but instances init faild\033[0m"
        fi
        exit
      else  # not install instance
        echo -e "\033[34mInstallNotice >>\033[0m \
        \033[32mOracle install successful, but there are no instances of installation\033[0m"
        exit
      fi
   fi
done
