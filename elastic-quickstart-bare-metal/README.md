# Quickstart Elastic Stack Install (Bare Metal)

If you would like to setup up a single stack quick and painlessly, I through all of the commands into a script. Being that I installed this on a Debian/Ubuntu server, the script has been setup to install Debian packages only.  

The script requires that some `sudo` commands be ran. This is for enabling services to autostart as well as modifying `/etc` files.

It also generates self-signed certificates to enable TLS between Kibana and one's browser.

When ran, the output should look similiar to this:
```
elastic-user@elastic:~$ ./elastic_stack.sh
Select a number corresponding to the version you'd like to download:
0)  8.1.1
1)  8.1.0
2)  8.0.1
3)  8.0.0
4)  7.17.1
5)  7.17.0
6)  7.16.3
7)  7.16.2
8)  7.16.1
9)  7.16.0
10)  Use default package that is set in the script
Enter number: 2
[*] Downloading Elasticsearch 8.0.1...
[*] Download Successful!
[*] Installing Elasticsearch...
[sudo] password for elastic-user:
[*] Elasticsearch Installed!
[!] Important output saved in elasticsearch_install.out
[*] Enabling Elasticsearch to autostart...
[*] Starting Elasticsearch...
[+] Successful Connection to Elasticsearch! :)
[*] Generating Kibana Enrollment Token...
[*] Downloading Kibana 8.0.1...
[*] Download Successful!
[*] Installing Kibana...
[+] Kibana Installed!
[*] Setting Up Kibana with Elasticsearch...
[+] Kibana Successfully Setup with Elasticsearch
Would you like to add a password to your self-signed keys?(y/n): n
[*] Creating self-signed certificates...
[+] Certificates created!
[*] Modifying kibana.yml with new settings...
[*] Enabling Kibana to autostart...
[*] Starting Kibana...
================================================================
==              Elasticsearch & Kibana Installed              ==
================================================================
[*] Now go to https://SERVER_IP:5601
[*] Login with:
    Username: elastic
    Password: IIOcw329s8jofYR6q5F6
```

To change the superuser password or generate enrollement tokens to add additional Elasticsearch nodes, the script outputs the initial config output the file `elasticsearch_install.out` which gives the needed commands.