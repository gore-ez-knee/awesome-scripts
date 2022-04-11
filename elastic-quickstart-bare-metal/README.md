# Quickstart Elastic Stack Install (Bare Metal)

### **10 Apr 2022 - Update**
> - Modified to pull the latest Elastic 8 versions instead of hard-coding them
> - Cut down on some of the output by overwriting some lines when a command either succeeds or fails
> - Cleaned up the downloaded files at the end

### **To-Do**
- Automatically detect OS and deploy accordingly. Need to get better at installing the 'tar.gz' files of Elasticsearch/Kibana
- Set this all up with Docker/Docker-Compose
- Allow for older installs, but will need to configure TLS for those older versions of Elasticsearch/Kibana
- Find a better way to automatically stand up a fleet-server. Could probably install a stand-alone agent with a conf file and instantiate it as a Fleet Server and link it to Elasticsearch/Kibana. I'll have to play around with it more.

If you would like to setup up a single stack quick and painlessly, I threw all of the commands into a script. Being that I installed this on a Debian/Ubuntu server, the script has been setup to install **Debian packages only**. Also this only works for Elastic version 8.0.0+ because Elastic v8 automatically creates TLS certificates for Elasticsearch communication and I haven't put checks in to create and update Elasticsearch should someone want to install an older version. 

The script requires that some `sudo` commands be ran. This is for enabling services to autostart as well as modifying `/etc` files.

It also generates self-signed certificates to enable TLS between Kibana and one's browser as well as for Fleet Server.

When ran, the output should look similiar to this:
```
elastic-user@elastic:~$ sudo ./elastic_stack.sh
[sudo] password for elastic-user:
Select a number corresponding to the version you'd like to download:
0)  8.1.1
1)  8.1.0
2)  8.0.1
3)  8.0.0
4)  Use Package Set in Script
Enter number: 0
[*] Downloading Elasticsearch 8.1.1...
[*] Elasticsearch 8.1.1 Download Successful!
[*] Installing Elasticsearch 8.1.1...
[+] Elasticsearch 8.1.1 Installed!
[!] Important output saved in elasticsearch_install.out
[*] Enabling Elasticsearch to autostart...
[*] Starting Elasticsearch...
[+] Successful Connection to Elasticsearch! :)
[*] Generating Kibana Enrollment Token...
[*] Downloading Kibana 8.1.1...
[*] Kibana 8.1.1 Download Successful!
[*] Installing Kibana 8.1.1...
[+] Kibana Installed!
[*] Setting Up Kibana with Elasticsearch...
[+] Kibana Successfully Setup with Elasticsearch
[?] Would you like to add a password to your self-signed keys?(y/n): y
Password:
Password (again):
[*] Creating self-signed certificates...
[+] Certificates created!
[*] Modifying kibana.yml with new settings...
[*] Generating Encryption Keys for Kibana and writing them to kibana.yml
[*] Enabling Kibana to autostart...
[*] Starting Kibana...
================================================================
==              Elasticsearch & Kibana Installed              ==
================================================================
[*] Now go to https://SERVER_IP:5601
[*] Login with:
    Username: elastic
    Password: Z=9ZGo9Kgva3Rg1EsDpA
================================================================
[?] Would you like to setup a Fleet Server?(y/n): y
[*] Downloading Elastic Agent 8.1.1...
[*] Elastic Agent 8.1.1 Download Successful!
[*] Installing Elastic Agent 8.1.1...
[+] Elastic agent 8.1.1 Installed!
[*] Generating a CA to create Fleet Server Certificates
[!] Need to install Unzip binary
[*] Creating Certificates for Fleet Server
================================================================
==                     Fleet-Server Setup                     ==
================================================================
[*] Go to Kibana -> Click on Fleet
[!] Step 1: Click on Create Policy
[*] Step 2: Ignore. Elastic Agent is already Downloaded
[*] Step 3: Choose "Quick start" for Deployment Mode
[*] Step 4: Type in https://SERVER_IP:8220 and click "Add host"
[*] Step 5: Click Generate Token
[*] Use the following template to enroll the Fleet Server
[*] Replace the 3 variables (SERVER_IP, FLEET_SERVER_TOKEN, & ELASTICSEARCH_CA_FINGERPRINT) with the information that Step 6 provides:
sudo elastic-agent enroll -f \
--url=https://SERVER_IP:8220 \
--fleet-server-es=https://SERVER_IP:9200 \
--fleet-server-service-token=FLEET_SERVER_TOKEN \
--fleet-server-policy=fleet-server-policy \
--fleet-server-es-ca-trusted-fingerprint=ELASTICSEARCH_CA_FINGERPRINT \
--certificate-authorities=/etc/elasticsearch/certs/ca/ca.crt \
--fleet-server-cert=/etc/elastic-agent/certs/fleet-server/fleet-server.crt \
--fleet-server-cert-key=/etc/elastic-agent/certs/fleet-server/fleet-server.key
[*] Once you have entered the command and the Agent shutsdown, start the agent:
sudo service elastic-agent start
[+] Check Fleet. You should see Fleet Server up and healthy!
```

To change the superuser password or generate enrollement tokens to add additional Elasticsearch nodes, the script outputs the initial config output to the file `elasticsearch_install.out` which gives the needed commands.