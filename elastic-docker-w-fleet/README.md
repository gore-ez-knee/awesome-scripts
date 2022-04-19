# Elastic Stack on Docker w/ Fleet

## **WIP**

Initally I tried to bootstrap Fleet with a container the same way as the sample `docker-compose.yaml` that Elastic provides uses an Elasticsearch container to setup the certificates for the cluster [[Reference]](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html).

Kept running into issues with networking and passing the service token to the variable. I was fortunate to have found a script which had a great idea of having the scipt build out the yaml files and setting up the services. I used their idea to test out the viability and it worked. They also knew the API commands to setup a Fleet Server and Fleet Server Policy which was a godsend. This is the script they made: https://raw.githubusercontent.com/jlim0930/scripts/master/deploy-elastic.sh


### Requirements:
- Docker
- Docker-Compose
- jq
- curl

*Don't forget to set the inital config of the vm.max_map_count*
 I needed to run this command

`sudo sysctl -w vm.max_map_count=262144`

and add this line to /etc/sysctl.conf

`vm.max_map_count = 262144`


- Need to pretty up the output
- Add arguments/choices for user to install fleet should they so choose
- Test to see if I can get away with using the Domain names specified in the certificates instead of hard-coding the IP address for Elasticsearch/Kibana/Fleet.
- Still having problems getting Agents to enroll w/ Fleet Server. I can see the Fleet Server enrolled, but can't seem to communicate with it.


### References:
- Godsend Script: https://raw.githubusercontent.com/jlim0930/scripts/master/deploy-elastic.sh
- Elastic - Multi-Node Stack w/ Docker: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- Elastic - Fleet Env Variables: https://www.elastic.co/guide/en/fleet/current/agent-environment-variables.html
- Inital Config for Environment: https://www.reddit.com/r/elasticsearch/comments/slcdom/trying_to_get_elasticsearch_and_kibana_working/