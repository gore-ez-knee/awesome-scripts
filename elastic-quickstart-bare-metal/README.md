# Quickstart Elastic Stack Install (Bare Metal)

### **18 Apr 2022 - Update**
> - Modified the script to automatically setup Fleet Server. I eventually realized I could use a proxy (Burp Suite) to capture the API calls used when manually setting up Fleet through the UI. Then I could create `curl` commands to have the script setup what is needed for Fleet.

### **10 Apr 2022 - Update**
> - Modified to pull the latest Elastic 8 versions instead of hard-coding them
> - Cut down on some of the output by overwriting some lines when a command either succeeds or fails
> - Cleaned up the downloaded files at the end

### **To-Do**
- Automatically detect OS and deploy accordingly. Need to get better at installing the 'tar.gz' files of Elasticsearch/Kibana
- Set this all up with Docker/Docker-Compose (Getting close)
- Allow for older installs, but will need to configure TLS for those older versions of Elasticsearch/Kibana

If you would like to setup up a single stack quick and painlessly, I threw all of the commands into a script. Being that I installed this on a Debian/Ubuntu server, the script has been setup to install **Debian packages only**. Also this only works for Elastic version 8.0.0+ because Elastic v8 automatically creates TLS certificates for Elasticsearch communication and I haven't put checks in to create and update Elasticsearch should someone want to install an older version. 

The script requires that some `sudo` commands be ran. This is for enabling services to autostart as well as modifying `/etc` files.

It also generates self-signed certificates to enable TLS between Kibana and one's browser as well as for Fleet Server.

Still working on getting this setup with Docker the same way...

When ran, the output should look similar to this:
```
elastic-user@elastic:~$ sudo ./elastic_stack.sh
[sudo] password for elastic-user:
Select a number corresponding to the version you'd like to download:
0)  8.1.2
1)  8.1.1
2)  8.1.0
3)  8.0.1
4)  8.0.0
Enter number: 0
Select a number corresponding the Server's IP: 
0)  192.168.235.133
Enter a number: 0
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
[*] Setting Up Fleet Agent Policy...DONE
[*] Snagging Service Token...DONE
[*] Getting Elasticsearch CA Fingerprint...DONE
[*] Adding Fleet Server host...DONE
[*] Enrolling Fleet...DONE
================================================================
==                   Fleet Server Installed                   ==
================================================================
```

To change the superuser password or generate enrollment tokens to add additional Elasticsearch nodes, the script outputs the initial config output to the file `elasticsearch_install.out` which gives the needed commands.