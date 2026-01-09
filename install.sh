#!/bin/bash
set -e
export TERM=${TERM:-xterm}

usage() {
	echo "$0: configura e instala as dependencias de seguranca e monitoria"
	echo 'Revision: 003'
	echo ""
	echo "Use: $0:                    Mostrar esta mensagem."
	echo "Use: $0 sysprep             Prepara o sistema para instalacao do IPBX"
	echo "Use: $0 installast          Instala o Asterisk+Freepbx"
	echo "Use: $0 installcr           Instala o Callrouting"
	echo "Use: $0 iptables            Configurar o iptables."
	echo "Use: $0 fail2ban            Configurar o fail2ban."
	echo "Use: $0 monitor             Instala o monitor de clientes."
	echo "Use: $0 installdeps         Instalar os pacotes necessarios para fail2ban. (Já foi executado durenate a instalação)"
	echo "Use: $0 configsegurancafpbx Configura protecoes FREEPBX. (Já foi executado durenate a instalação)"
	echo "Use: $0 installagidnis      Instala AGI DNIS" 
    echo "Use: $0 installnodered      Instala Node Red" 
	echo "Use: $0 clean               Efetua a limpeza dos arquivos temporarios e instaladores"
}
installagidnis()
{
	set +e
	rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
	yum install dotnet-sdk-6.0 -y
	yum install dotnet-sdk-7.0 -y
	mkdir -p /var/lib/asterisk/sounds/tts/
	mkdir -p /var/www/html/stt/
	mkdir -p /var/agecom/callroutingagi/
	cp -f /protecao/agi/dnis/*.dll /var/agecom/callroutingagi/
	cp -f /protecao/agi/dnis/*.json /var/agecom/callroutingagi/
	cp -f /protecao/agi/dnis/*.pdb /var/agecom/callroutingagi/
	cp -f /protecao/agi/dnis/sounds/*.wav /var/lib/asterisk/sounds/
	cp -f /protecao/agi/dnis/sounds/*.mp3 /var/lib/asterisk/sounds/
	cp -Rf /protecao/agi/dnis/sounds/moh /var/lib/asterisk/
chown -R asterisk:asterisk /var/lib/asterisk/sounds/tts/
chown -R asterisk:asterisk /var/www/html/stt/
chown -R asterisk:asterisk /protecao/agi/dnis/sounds/moh/
ln -s /usr/local/bin/lame /bin/lame
dnf install sox -y
echo -e "[Unit]" > /usr/lib/systemd/system/agidnis.service
echo -e "Description=AGI Callrouting" >> /usr/lib/systemd/system/agidnis.service
echo -e "After=httpd.service" >> /usr/lib/systemd/system/agidnis.service

echo -e "[Service]" >> /usr/lib/systemd/system/agidnis.service
echo -e "WorkingDirectory=/var/agecom/callroutingagi" >> /usr/lib/systemd/system/agidnis.service
echo -e "Type=simple" >> /usr/lib/systemd/system/agidnis.service
echo -e "User=root" >> /usr/lib/systemd/system/agidnis.service
echo -e "ExecStart=/usr/bin/dotnet /var/agecom/callroutingagi/CallroutingAgiRoutingDNIS.dll" >> /usr/lib/systemd/system/agidnis.service
echo -e "Restart=always" >> /usr/lib/systemd/system/agidnis.service
echo -e "RestartSec=5" >> /usr/lib/systemd/system/agidnis.service
echo -e "ExecReload=/bin/kill -HUP $MAINPID" >> /usr/lib/systemd/system/agidnis.service
echo -e "" >> /usr/lib/systemd/system/agidnis.service
echo -e "" >> /usr/lib/systemd/system/agidnis.service
echo -e "[Install]" >> /usr/lib/systemd/system/agidnis.service
echo -e "WantedBy=multi-user.target" >> /usr/lib/systemd/system/agidnis.service

echo -e "[typing]" >> /etc/asterisk/musiconhold_custom.conf
echo -e "mode=files" >> /etc/asterisk/musiconhold_custom.conf
echo -e "sort=alpha" >> /etc/asterisk/musiconhold_custom.conf
echo -e "directory => /var/lib/asterisk/moh/typing" >> /etc/asterisk/musiconhold_custom.conf

systemctl enable agidnis.service
systemctl start agidnis.service
set -e

}
cleansys()
{
	cd /
	set +e
	dnf clean all
	rm -Rf /usr/src/asterisk/freepbx*
	rm -Rf /protecao
	rm -f /var/www/html/admin/modules/_cache/*
	set -e
}
configrepomariadb()
{
	echo -e "# MariaDB 10.6 RedHat repository list - created 2023-01-30 17:32 UTC
# https://mariadb.org/download/
[mariadb]
name = MariaDB
baseurl = https://mirrors.gigenet.com/mariadb/yum/11.5/rhel$(rpm -E %rhel)-amd64
module_hotfixes=1
gpgkey=https://mirrors.gigenet.com/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1" > /etc/yum.repos.d/MariaDB.repo
}
sysprep()
{
	set +e
        sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/sysconfig/selinux
        sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config
	dnf install langpacks-en glibc-all-langpacks -y
        
	set -e
	curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-11.5"
#        configrepomariadb
        dnf -y upgrade
        timedatectl set-timezone America/Sao_Paulo
	export LC_ALL=pt_BR.UTF-8
	localectl set-locale LANG=pt_BR.UTF-8
        dnf -y install epel-release epel-next-release
        dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm
	dnf -y install https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$(rpm -E %rhel).noarch.rpm
        dnf -y install dnf-plugins-core mc mlocate esmtp-local-delivery
	dnf config-manager --set-enabled crb
        if [ $centosversion -eq "8" ] ; then
                        yum config-manager --set-enabled powertools
        fi
        dnf -y install lynx tftp-server unixODBC mariadb-server mariadb mariadb-connector-odbc httpd ncurses-devel sendmail sendmail-cf newt-devel libxml2-devel libcurl-devel libtiff-devel gtk2-devel subversion git wget vim sqlite-devel net-tools gnutls-devel texinfo libuuid-devel libedit-devel tar crontabs gcc gcc-c++ openssl-devel openssl-perl openssl-pkcs11 mysql-devel libxslt-devel kernel-devel fail2ban postfix mod_ssl nodejs
        if [ $centosversion -ge "8" ] ; then
                        dnf -y install unixODBC-devel libogg-devel libvorbis-devel uuid-devel libtool-ltdl-devel libsrtp-devel libtiff-tools
        fi

        dnf -y remove php*
        dnf -y install https://rpms.remirepo.net/enterprise/remi-release-$centosversion.rpm
        dnf -y module disable php
        dnf -y module enable php:remi-7.4
        dnf install -y openssh-server php php-pdo php-mysqlnd php-mbstring php-pear php-process php-xml php-opcache php-ldap php-intl php-soap php-json
        dnf install -y https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.32-1.el8.x86_64.rpm
#       dnf install https://rpmfind.net/linux/centos/$centosversion-stream/AppStream/x86_64/os/Packages/mariadb-connector-odbc-3.1.12-1.el8.x86_64.rpm
        dnf -y install https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm
#        dnf -y install https://forensics.cert.org/cert-forensics-tools-release-el$(rpm -E %rhel).rpm
        sed -i 's/\/lib\/libmyodbc5.so/\/lib64\/libmyodbc8a.so/' /etc/odbcinst.ini
        sed -i 's/\/lib64\/libmyodbc5.so/\/lib64\/libmyodbc8a.so/' /etc/odbcinst.ini
if [ $centosversion -eq "9" ] ; then
        dnf -y install https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm
        dnf -y install https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-9.noarch.rpm
fi
installdeps
set +e
        dnf -y install ffmpeg
        dnf -y install sox
	dnf -y install ffmpeg
        systemctl start sshd
	systemctl enable sshd
	systemctl stop firewalld
	systemctl disable firewalld
        dnf remove firewalld -y
	systemctl enable mariadb
	systemctl start mariadb
	sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
set -e

        while true; do
                read -p "Preparacao do sistema finalizada. Deseja reiniciar o sistema agora? " preboot
                case $preboot in
                        [SsYy]* ) reboot; break;;
                        [Nn]* ) echo -e "Pulando reiniciar o sistema.
                                ${RED}Podem ocorrer erros ao tentar prosseguir com as demais etapas!${NC}"; break;;
                        * ) echo "RESPONDA sim ou nao.";;
                esac
        done
}
installdahdi()
{
	        set +e
        rm -f dahdi-linux-complete-current.tar.gz
        rm -f libpri-current.tar.gz
        wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
        wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-current.tar.gz
        wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/openr2/openr2-1.3.3.tar.gz
        tar xvfz dahdi-linux-complete-current.tar.gz
        tar xvfz libpri-current.tar.gz
        tar xvzf openr2-1.3.3.tar.gz
        cd /usr/src/asterisk/dahdi-linux-complete-3*
        make all
        make install
        make install-config
        cd /usr/src/asterisk/libpri-1.6.*
        make
        make install
        cd /usr/src/asterisk/openr2-1.3.3
        ./configure
        make -j8
        make install
	set -e

}
installasterisk()
{
set +e
	mkdir /var/run/asterisk
mkdir /var/log/asterisk
mkdir /root/.ssh ; echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIB1OVcsigLtFLEu4nEK1xgttCPPwRaSHhAaQBm2I08LhLtZ1OZsJObbAq3eYlfI7JoAnfdOLpluQcchkY6c7E8lt+Jb6yBH2m9NVE3rMIoZx0cWNGNjz4fkDm5+1z0pOgNTQXBrx4cG5r6kNfRQhzZSrlFSWG13w/wfBeLummWFnw== rsa-key-20101112" > /root/.ssh/authorized_keys
useradd -c "Asterisk PBX" -d /var/lib/asterisk asterisk; echo AgEcOm2o4o@ | passwd asterisk --stdin
mkdir -p /usr/src/asterisk
set -e
systemctl enable httpd.service
systemctl start httpd.service
dnf -y install elfutils-libelf-devel
cd /usr/src/asterisk
rm -f asterisk-*-current.tar.gz
 while true; do
                read -p "Deseja ativar o suporte a DAHDI? " supdahdi
                case $supdahdi in
                        [SsYy]* ) installdahdi; break;;
                        [Nn]* ) break;;
                        * ) echo "RESPONDA sim ou nao.";;
                esac
        done
cd /usr/src/asterisk
wget -t 3 -timeout=30 -timestamp http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz
dnf -y install jansson
cd /usr/src/asterisk
tar xvfz asterisk-18-current.tar.gz
cd asterisk-*/
contrib/scripts/install_prereq install
./configure --with-jansson-bundled --libdir=/usr/lib64
set +e
contrib/scripts/get_mp3_source.sh
make
make menuselect.makeopt
menuselect/menuselect --enable cdr_mysql menuselect.makeopts
menuselect/menuselect --enable app_macro menuselect.makeopts
menuselect/menuselect --enable format_mp3 menuselect.makeopts
menuselect/menuselect --disable chan_alsa menuselect.makeopts
menuselect/menuselect --disable chan_skinny menuselect.makeopts
menuselect/menuselect --disable chan_mgcp menuselect.makeopts
set -e
make -j8
make install
set +e
make config
systemctl disable asterisk
set -e
touch /etc/asterisk/{modules,cdr,smdi}.conf
ldconfig
ln -s /usr/lib64/asterisk /usr/lib/asterisk
cd /usr/lib64/asterisk/modules && wget -t 1 --timeout=30 --timestamping http://asterisk.hosting.lv/bin/codec_g729-ast180-gcc4-glibc-x86_64-core2.so
chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /var/{lib,log,spool}/asterisk
chown -R asterisk. /usr/lib64/asterisk
chown -R asterisk. /var/www/
sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php.ini
sed -i 's/\(^memory_limit = \).*/\1256M/' /etc/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
sed -i 's/\(^user = \).*/\1asterisk/' /etc/php-fpm.d/www.conf
sed -i 's/\(^group = \).*/\1asterisk/' /etc/php-fpm.d/www.conf
sed -i 's/\(^listen.acl_users = apache,nginx\).*/\1,asterisk/' /etc/php-fpm.d/www.conf
systemctl restart httpd.service
systemctl restart php-fpm
cd /usr/src/asterisk
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-16.0-latest.tgz
tar xfz freepbx-16.0-latest.tgz
cd freepbx
./start_asterisk start
./install --force --no-interaction
fwconsole ma upgradeall
set +e
fwconsole ma download versionupgrade
fwconsole ma enable versionupgrade
fwconsole ma install versionupgrade
set -e
fwconsole ma downloadinstall soundlang weakpasswords ringgroups sipsettings recordings queues parking music iaxsettings featurecodeadmin conferences bulkhandler backup callforward callrecording callwaiting core framework dashboard donotdisturb logfiles;fwconsole r; fwconsole ma upgradeall; fwconsole r; fwconsole chown 
set +e
fwconsole versionupgrade --upgrade;fwconsole r
fwconsole ma upgradeall

fwconsole setting SIGNATURECHECK 0
fwconsole setting LAUNCH_AGI_AS_FASTAGI 0
fwconsole setting FREEPBX_SYSTEM_IDENT $HOSTNAME
fwconsole setting RSSFEEDS ""
fwconsole setting PHPTIMEZONE America/Sao_Paulo
fwconsole setting UIDEFAULTLANG pt_BR
fwconsole setting TIMEFORMAT "24 Hour Format"
fwconsole setting TONEZONE br
fwconsole setting ASTSIPDRIVER both

mariadb-admin -u root password 'Agecom20402040'
configsegurancafpbx Agecom20402040
echo -e "[Unit]" > /usr/lib/systemd/system/freepbx.service
echo -e "Description=IPBX VoIP Server" >> /usr/lib/systemd/system/freepbx.service
echo -e "After=mariadb.service" >> /usr/lib/systemd/system/freepbx.service
echo -e "" >> /usr/lib/systemd/system/freepbx.service
echo -e "[Service]" >> /usr/lib/systemd/system/freepbx.service
echo -e "Type=oneshot" >> /usr/lib/systemd/system/freepbx.service
echo -e "RemainAfterExit=yes" >> /usr/lib/systemd/system/freepbx.service
echo -e "ExecStart=/usr/sbin/fwconsole start" >> /usr/lib/systemd/system/freepbx.service
echo -e "ExecStop=/usr/sbin/fwconsole stop" >> /usr/lib/systemd/system/freepbx.service
echo -e "" >> /usr/lib/systemd/system/freepbx.service
echo -e "[Install]" >> /usr/lib/systemd/system/freepbx.service
echo -e "WantedBy=multi-user.target" >> /usr/lib/systemd/system/freepbx.service
systemctl disable asterisk
systemctl enable freepbx
systemctl enable httpd
fwconsole reload
set -e
ln -s /usr/lib64/libmyodbc8w.so /usr/lib64/libmyodbc8.so
}

installcr()
{
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %rhel)-x86_64/pgdg-redhat-repo-latest.noarch.rpm
dnf -qy module disable postgresql
dnf install -y postgresql16-server
dnf install -y postgresql16-contrib
/usr/pgsql-16/bin/postgresql-16-setup initdb
systemctl enable postgresql-16
systemctl start postgresql-16
#dnf -y module enable postgresql:13
#dnf -y install postgresql-*
dnf -y install mono-complete mc
echo -e "nice -n 10 /usr/local/bin/lame --preset phone -h -m m /var/spool/asterisk/monitor/\$1" > /usr/lib/asterisk/conv_mp3.sh
echo -e "rm -f /var/spool/asterisk/monitor/\$1" >> /usr/lib/asterisk/conv_mp3.sh
chmod 777 /usr/lib/asterisk/conv_mp3.sh
#postgresql-setup --initdb
#systemctl start postgresql
#systemctl enable postgresql

su -c "psql -d postgres -c \"CREATE ROLE callproadmin LOGIN ENCRYPTED PASSWORD 'md590dd535ee60b5c53be83ce36915873e2' SUPERUSER INHERIT NOCREATEDB NOCREATEROLE REPLICATION;\"" postgres
su -c "psql -d postgres -c \"CREATE ROLE gravador LOGIN ENCRYPTED PASSWORD 'md56c7506e8717c4c44786600be925f2bc3' SUPERUSER NOINHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;\"" postgres
su -c "psql -d postgres -c \"CREATE DATABASE callpro WITH OWNER = gravador ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'pt_BR.UTF-8' LC_CTYPE = 'pt_BR.UTF-8' CONNECTION LIMIT = -1;\"" postgres
su -c "psql -d postgres -c \"CREATE DATABASE gravador WITH OWNER = gravador ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'pt_BR.UTF-8' LC_CTYPE = 'pt_BR.UTF-8' CONNECTION LIMIT = -1;\"" postgres

sed -i 's/\(^#port\).*/\port = 5432/' /var/lib/pgsql/16/data/postgresql.conf
sed -i 's/\(^max_connections\).*/\max_connections = 1000/' /var/lib/pgsql/16/data/postgresql.conf
export listen_addresses="listen_addresses = '*'"
sed -i "s/#listen_addresses.*/$listen_addresses/" /var/lib/pgsql/16/data/postgresql.conf
sed -i '83 i\host    all             all             0.0.0.0 0.0.0.0         md5' /var/lib/pgsql/16/data/pg_hba.conf
tar -xvzf adds/asterisk.tar.gz -C /
asterisk -rx 'core restart now'
runuser -l postgres -c "psql callpro < /protecao/SQL/callpro.sql"
runuser -l postgres -c "psql gravador < /protecao/SQL/gravador.sql"

cd /usr/src
wget https://downloads.sourceforge.net/lame/lame-3.100.tar.gz
tar zxvf lame-3.100.tar.gz
cd lame-3.100
./configure
make
make install

wget --timestamping http://ipbx.agecomnet.com.br/callroute.tar.gz && tar -xvzf callroute.tar.gz -C /
cp -f /protecao/callrouting/Callroute-pro.ini /var/agecom/callroute/
rm -f callroute.tar.gz
rm -f /var/agecom/callroute/lame.exe
cp /usr/local/bin/lame /var/agecom/callroute/lame.exe
cd /usr/src/asterisk
mkdir -p /usr/src/asterisk/mp3gain
cd /usr/src/asterisk/mp3gain
wget "https://downloads.sourceforge.net/project/mp3gain/mp3gain/1.5.2/mp3gain-1_5_2_r2-src.zip?r=https%3A%2F%2Fwww.google.com.br%2F&ts=1511364598&use_mirror=ufpr"
unzip mp3*
make && make install
rm -f /var/agecom/callroute/mp3gain.exe
cp /usr/src/asterisk/mp3gain/mp3gain /var/agecom/callroute/mp3gain.exe



echo -e [Unit] > /etc/systemd/system/callroute.service
echo -e >> /etc/systemd/system/callroute.service
echo -e Description=Callrouting Service>> /etc/systemd/system/callroute.service
echo -e After=freepbx.service>> /etc/systemd/system/callroute.service
echo -e >> /etc/systemd/system/callroute.service
echo -e [Service]>> /etc/systemd/system/callroute.service
echo -e Type=simple>> /etc/systemd/system/callroute.service
echo -e User=root>> /etc/systemd/system/callroute.service
echo -e ExecStart=/var/agecom/callroute/start_callroute.sh>> /etc/systemd/system/callroute.service
echo -e Restart=on-abort>> /etc/systemd/system/callroute.service
echo -e >> /etc/systemd/system/callroute.service
echo -e >> /etc/systemd/system/callroute.service
echo -e [Install]>> /etc/systemd/system/callroute.service
echo -e WantedBy=multi-user.target>> /etc/systemd/system/callroute.service
systemctl enable callroute.service
systemctl start callroute.service
systemctl restart postgresql-16
cp -f /usr/local/bin/lame /var/agecom/callroute/lame.exe

}
installdeps()
{
	yum -y install epel-release
	yum -y install fail2ban fail2ban-systemd GeoIP GeoIP-data GeoIP-GeoLite-data iptables-services mariadb
	systemctl disable firewalld
	systemctl stop firewalld
}
installmonitor()
{
	cd /bin
	wget -t 1 --timeout=30 --timestamping https://ipbx.agecomnet.com.br/coletaeventos.sh
	chmod 777 /bin/coletaeventos.sh
	cd -
	line="0 * * * * /bin/coletaeventos.sh"
	if [ -f "/var/spool/cron/root" ]; then
		currentcrontab=$(crontab -u root -l)
		if [[ "$currentcrontab" == *"$line"* ]]; then
			echo -e "Já existe o coleta evento no crontab abortando"
		else
			echo -e "Criando coleta evento no crontab"
			if [ -f "/var/spool/cron/root" ]; then
				(crontab -u root -l; echo "$line" ) | crontab -u root -
			else
				echo "$line"  | crontab -u root
			fi
		fi
	else
		echo -e "Criando coleta evento no crontab"
		echo "$line"  | crontab -u root -
	fi


	#	(crontab -u root -l; echo "$line" ) | crontab -u root -

}
configfreepbxf2b()
{
	read -p "Digite a senha do MYSQL? " mysqlpass
	/usr/sbin/fwconsole ma downloadinstall logfiles
	/usr/bin/mariadb -p$mysqlpass asterisk << EOF
INSERT logfile_logfiles (name,permanent,readonly,disabled,debug,dtmf,error,fax,notice,verbose,warning,security) values ('security','0','0','0','off','off','off','off','off','off','off','on');
EOF
/usr/sbin/fwconsole r
}
configsegurancafpbx()
{
mariadb -pAgecom20402040 asterisk << EOF
update asterisk.featurecodes set enabled='0',defaultcode=' ',customcode=' ' where featurename='blindxfer'; update soundlang_settings set value='g722,g729,ulaw' where keyword='formats';update soundlang_settings set value= 'pt_BR' where keyword='language'; insert into soundlang_customlangs (language,description) values ('pt_BR','Brazil');update sipsettings set data='5588' where keyword='bindport';update sipsettings set data='5589' where keyword='tlsbindport';
EOF
cp -Rf /protecao/asterisk/sounds/* /var/lib/asterisk/sounds/

mariadb -pAgecom20402040 asteriskcdrdb < /protecao/SQL/freepbx.sql
}
setdosasynprotection()
{
	echo -e "net.ipv4.conf.all.log_martians = 1" > /etc/sysctl.conf
	echo -e "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
	echo -e "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf
	echo -e "net.ipv4.conf.default.secure_redirects = 0" >> /etc/sysctl.conf
	echo -e "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
	echo -e "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
	echo -e "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
	echo -e "net.ipv4.conf.default.rp_filter = 1" >> /etc/sysctl.conf
	if [ $1 -eq 1 ]
	then
		echo -e "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
	fi
	sysctl -p >/dev/null
}
setiptablesfile()
{
	echo -e "*filter" > /etc/sysconfig/iptables
	echo -e ":INPUT DROP [0:0]" >> /etc/sysconfig/iptables
	echo -e ":FORWARD ACCEPT [0:0]" >> /etc/sysconfig/iptables
	echo -e ":OUTPUT ACCEPT [0:0]" >> /etc/sysconfig/iptables
	echo -e "#               Liberacoes padrao, nao alterar sem previa autorizacao." >> /etc/sysconfig/iptables
	echo -e "# IPs confiaveis, redes locais e loopback" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -i lo -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 127.0.0.1 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 192.168.0.0/16 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 172.16.0.0/16 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 10.0.0.0/8 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 179.110.69.216 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 200.49.34.48/29 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 189.126.200.240/28 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 200.155.163.48/29 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 200.201.138.240/28 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 18.231.140.201 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 189.19.223.154 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -s 179.110.69.59 -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "# Inicio da area para liberacao de IPs personalizados" >> /etc/sysconfig/iptables
	echo -e "# Fim da area para liberacao de IPs personalizados" >> /etc/sysconfig/iptables
	echo -e "#               Portas dos servicos" >> /etc/sysconfig/iptables
	echo -e "# Porta SSH" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -p tcp -m tcp --dport $sshport -j ACCEPT" >> /etc/sysconfig/iptables
	if [ -f "/etc/httpd/conf/httpd.conf" ]
	then
		echo -e "# Porta HTTP" >> /etc/sysconfig/iptables
		echo -e "-A INPUT -p tcp -m tcp --dport $httplistenport -j ACCEPT" >> /etc/sysconfig/iptables
	fi
	echo -e "# Portas IPBX" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -p udp -m udp --dport $sipport -j ACCEPT" >> /etc/sysconfig/iptables
	for i in "${pjsipports[@]}"
	do :
		echo -e "-A INPUT -p udp -m udp --dport $rtpstart:$rtpend -j ACCEPT" >> /etc/sysconfig/iptables
		echo -e "-A INPUT -p udp -m udp --dport $i -j ACCEPT" >> /etc/sysconfig/iptables
	done
	if [ -f "/var/agecom/callroute/Callroute-pro.ini" ]
	then
		echo -e "# Porta PostgreSQL" >> /etc/sysconfig/iptables
		echo -e "-A INPUT -p tcp -m tcp --dport 5432 -j ACCEPT" >> /etc/sysconfig/iptables
		echo -e "# Portas Callrouting" >> /etc/sysconfig/iptables
		echo -e "-A INPUT -p tcp -m tcp --dport $callroutingxmlrpc -j ACCEPT" >> /etc/sysconfig/iptables
		for i in "${callroutingports[@]}"
		do :
			echo -e "-A INPUT -p tcp -m tcp --dport $i -j ACCEPT" >> /etc/sysconfig/iptables
		done
	fi
	echo -e "# Inicio da area para liberacao de portas personalizadas" >> /etc/sysconfig/iptables
	echo -e "# Fim da area para liberacao de portas personalizadas" >> /etc/sysconfig/iptables
	echo -e "# Conexao de retorno" >> /etc/sysconfig/iptables
	echo -e "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A OUTPUT -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT" >> /etc/sysconfig/iptables
	echo -e "-A OUTPUT -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT" >> /etc/sysconfig/iptables

	echo -e "COMMIT" >> /etc/sysconfig/iptables
	if [ $1 -eq 1 ]
	then
		echo -e "*nat" >> /etc/sysconfig/iptables
		echo -e ":PREROUTING ACCEPT [0:0]" >> /etc/sysconfig/iptables
		echo -e ":POSTROUTING ACCEPT [0:0]" >> /etc/sysconfig/iptables
		echo -e ":OUTPUT ACCEPT [0:0]" >> /etc/sysconfig/iptables
		echo -e "COMMIT" >> /etc/sysconfig/iptables
	fi
	/bin/systemctl restart iptables.service
	/bin/systemctl restart fail2ban.service
}
configfail2ban()
{
	while true; do
		read -p "Configurar FreePBX para Fail2Ban? " ff2b
		case $ff2b in
			[SsYy]* ) configfreepbxf2b; break;;
			[Nn]* ) echo -e "Pulando configuracao FreePBX"; break;;
			* ) echo "RESPONDA sim ou nao.";;
		esac
	done

	rm -Rf /etc/fail2ban
	cp -Rf ./fail2ban /etc
	echo -e "# - Store banned IP in SQL db while it's banned." > /etc/fail2ban/action.d/banned_db.conf
	echo -e "# - Remove banned IP from SQL db while it's unbanned." >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "[Definition]" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "actionstart =" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "actioncheck =" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "actionban   = /usr/local/bin/fail2ban_banned_db ban <ip> <port> <protocol> <name> <ipjailfailures> <ipjailmatches>" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "actionunban = /usr/local/bin/fail2ban_banned_db unban <ip>" >> /etc/fail2ban/action.d/banned_db.conf
	echo -e "actionstop  = /usr/local/bin/fail2ban_banned_db cleanup <name>" >> /etc/fail2ban/action.d/banned_db.conf
	cp ./adds/fail2ban_banned_db /usr/local/bin/
	chmod 0550 /usr/local/bin/fail2ban_banned_db
	/bin/systemctl restart fail2ban.service
	/bin/systemctl enable fail2ban.service
}
configiptables()
{
	httplistenport=$(grep 'Listen' /etc/httpd/conf/httpd.conf | grep -v '^#' | cut -d " " -f2)
	sshport=$(grep 'Port ' /etc/ssh/sshd_config | grep -v '^#' | cut -d " " -f2)
	sipport=$(grep 'udpbindaddr' /etc/asterisk/sip_general_additional.conf | grep -v '^#' | cut -d ":" -f2)
	rtpstart=$(grep 'rtpstart=' /etc/asterisk/rtp_additional.conf | grep -v '^#' | cut -d "=" -f2)
	rtpend=$(grep 'rtpend=' /etc/asterisk/rtp_additional.conf | grep -v '^#' | cut -d "=" -f2)
	pjsipports=$(grep 'bind=' /etc/asterisk/pjsip.transports.conf | grep -v '^#' | cut -d ":" -f2 | grep -v '^bind')
	if [ -f "/var/agecom/callroute/Callroute-pro.ini" ]
	then

		callroutingports=$(grep -i 'port =' /var/agecom/callroute/Callroute-pro.ini | grep -v '^Manager' | cut -d "=" -f2 | sed -e 's/^[[:space:]]*//')
		callroutingxmlrpc=$(grep XMLRPC /var/agecom/callroute/Callroute-pro.ini | cut -d "=" -f2| sed -e 's/^[[:space:]]*//')
	fi
	readarray -t callroutingports <<<"$callroutingports"

	#IFS='\n' read -r -a callroutingports <<< "$string"

	for i in "${pjsipports[@]}"
	do
		:
		if [ $i -eq 5060 ]
		then
			echo -e "${RED} Porta PJSIP padrao(5060),${NC} favor alterar"
		fi
	done
	if [ -z "$sshport" ]
	then
		sshport=22
		echo -e "${RED} Porta SSH padrao(22),${NC} favor alterar"
	fi

	while true; do
		read -p "Deseja ativar o compartilhamento de internet? " internetshare
		case $internetshare in
			[SsYy]* ) setdosasynprotection 1; break;;
			[Nn]* ) setdosasynprotection 0; break;;
			* ) echo "RESPONDA sim ou nao.";;
		esac
	done
	case $internetshare in
		[SsYy]* ) setiptablesfile 1; break;;
		[Nn]* ) setiptablesfile 0; break;;
	esac
}
installnodered() {
    echo "==> Verificando Node.js instalado..."
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node -v | sed 's/v//')
        echo "Node.js encontrado: v$NODE_VERSION"
    else
        NODE_VERSION="0.0.0"
        echo "Node.js não encontrado."
    fi

    REQUIRED_VERSION="20.0.0"
    version_lt() { [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]; }

    if version_lt "$NODE_VERSION" "$REQUIRED_VERSION"; then
        echo "Atualizando Node.js..."
        dnf -y remove nodejs || true
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        dnf -y install nodejs
    else
        echo "Node.js já está atualizado (>= $REQUIRED_VERSION)"
    fi

    echo "==> Instalando Node-RED e PM2..."
    npm install -g --unsafe-perm node-red pm2

    echo "==> Instalando módulos adicionais..."
    npm install -g @flowfuse/node-red-dashboard node-red-contrib-contextbrowser node-red-debugger bcryptjs
	node-red --userDir /root/.node-red &
    sleep 5
    pkill -f node-red
    echo "==> Ajustando configuração do Node-RED..."
    SETTINGS_FILE="$HOME/.node-red/settings.js"

    # cria settings.js se não existir
    mkdir -p "$HOME/.node-red"
    if [ ! -f "$SETTINGS_FILE" ]; then
        node-red --settings "$SETTINGS_FILE" --help >/dev/null 2>&1 || true
    fi

BACKUP_FILE="/root/.node-red/settings.js.bak.$(date +%F-%H%M)"

echo "==> Fazendo backup de $SETTINGS_FILE em $BACKUP_FILE"
cp "$SETTINGS_FILE" "$BACKUP_FILE"

# Remove qualquer linha contendo adminAuth ou contextStorage (comentada ou não)
grep -v "adminAuth" "$BACKUP_FILE" | grep -v "contextStorage" > "$SETTINGS_FILE"

# Agora injeta os blocos novos logo após "module.exports = {"
awk '
/module.exports = {/ {
    print
    print "    contextStorage: {"
    print "        default: {"
    print "            module:\"localfilesystem\""
    print "        },"
    print "    },"
    print ""
    print "    adminAuth: {"
    print "        type: \"credentials\","
    print "        users: [{"
    print "            username: \"agecom\","
    print "            password: \"$2b$08$KagLCfJgAzK8ubpoSPtBOOEh16Cy0SMGiBziEROqdiCylA1MuhSWO\","
    print "            permissions: \"*\""
    print "        }]"
    print "    },"
    next
}
{print}
' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

echo "==> Blocos adminAuth e contextStorage aplicados com sucesso!"


    echo "==> Configurando Node-RED no PM2..."
    pm2 start $(which node-red) --name nodered -- -v
    pm2 save
    pm2 startup systemd -u $(whoami) --hp $(eval echo ~$USER)

    echo "==> Instalação concluída!"
    node -v
    npm -v
    node-red --version
    pm2 list
	
    echo "==> Chamando configuração do Apache..."
    configure_apache
    echo "==> Instalação concluída!"
}
configure_apache() {
    CONF_FILE="/etc/httpd/conf/httpd.conf"
    BLOCK_START="# >>> Node-RED Reverse Proxy >>>"
    BLOCK_END="# <<< Node-RED Reverse Proxy <<<"

    BLOCK_CONTENT=$(cat <<'EOF'
ProxyPreserveHost On
AllowEncodedSlashes NoDecode

RewriteEngine On
# redireciona sem barra final
RewriteRule ^/callroutingivr$ /callroutingivr/ [R=301,L]

# Proxy HTTP normal
ProxyPass        /callroutingivr/  http://127.0.0.1:1880/ timeout=60
ProxyPassReverse /callroutingivr/  http://127.0.0.1:1880/

# WebSocket Node-RED
ProxyPassMatch   ^/callroutingivr/comms/(.*)       ws://127.0.0.1:1880/comms/$1
ProxyPassReverse ^/callroutingivr/comms/(.*)       ws://127.0.0.1:1880/comms/$1

# WebSocket Dashboard (socket.io)
ProxyPassMatch   ^/callroutingivr/ui/socket.io/(.*) ws://127.0.0.1:1880/ui/socket.io/$1
ProxyPassReverse ^/callroutingivr/ui/socket.io/(.*) ws://127.0.0.1:1880/ui/socket.io/$1
EOF
)

    echo "==> Configurando Apache em $CONF_FILE ..."
    if grep -q "$BLOCK_START" "$CONF_FILE"; then
        echo "Bloco Node-RED já existe, não será duplicado."
    else
        {
            echo ""
            echo "$BLOCK_START"
            echo "$BLOCK_CONTENT"
            echo "$BLOCK_END"
        } | tee -a "$CONF_FILE" >/dev/null
        echo "Bloco Node-RED adicionado ao $CONF_FILE"
    fi

    echo "==> Reiniciando Apache..."
    systemctl restart httpd
}

centosversion=`cat /etc/centos-release | tr -dc '0-9.'`
RED='\033[0;31m'
NC='\033[0m' # No Color
clear;
echo -e "
############################################################
#                                                          # 
#                     Instalador/Protecao                  #
#                                                          #  
#                   Agecom Telecomunicações                #
#                    Nao modificar o script                #
#                          V1.0.2.0                        #	
#                                                          #
############################################################
"
case "$1" in
	sysprep)
		sysprep
		;;
	installast)
		installasterisk
		;;
	installcr)
		installcr
                ;;
	iptables)
		configiptables
		;;
	fail2ban)
		configfail2ban
		;;

	installdeps)
		installdeps
		;;
	monitor)
		installmonitor
		;;
	configsegurancafpbx)
		configsegurancafpbx
		;;
	clean)
		cleansys
		;;
	installagidnis)
		installagidnis
		;;
  	installnodered)
   		installnodered
	 	;;
	'')
		usage
		exit 0
		;;
	*)
		usage
		exit 1
		;;
esac


