##  INSTALL PIHOLE ON LXC 

```Bash
export PIHOLE_SELINUX=true
curl -sSL https://install.pi-hole.net | bash
```




## POSTINSTALL 

### Set password
```Bash
pihole setpassword <YourSecurePassword>
```

### Adding your local user to the 'pihole' group
```Bash
sudo usermod -aG pihole $USER
```

### Open port
```Bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```


## ADD BLOCKLISTS TO PIHOLE 

### Required package
```Bash
dnf install -y sqlite3
```

### Add Skillmio’s Hosts
```Bash
sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/skillmio/dns/master/files/hosts', 1, 'Skillmio’s Hosts');"
```


### Add Source-Saraiva’s Inherited Hosts
```Bash
sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/skillmio/dns/master/files/primelist', 1, 'Source-Saraiva’s Hosts');"
```

### Add Steven Black’s Hosts
```Bash
sudo sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'Steven Black’s Hosts');"
```

### Update list
```Bash
pihole -g
```


## DOWNLOAD AND EXECUTE SCRIPT 
```Bash
cd /tmp/
wget https://raw.githubusercontent.com/skillmio/dns/master/scripts/export-domains.sh
chmod +x export-domains.sh
./export-domains.sh
```


### UPDATE DOMAIN-BLIST 
After copy and paste content to domain-blist

### CLEANUP YOUR PI-HOLE SERVER
```Bash
rm -f /tmp/*.txt
```


