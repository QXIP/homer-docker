
![homer](http://i.imgur.com/ViXcGAD.png)

# HOMER 5 Docker
http://sipcapture.org

A simple recipe:

* debian/jessie (base image)
* Kamailio:9060 (sipcapture module)
* Apache2/PHP:80 (homer ui/api)
* MySQL/InnoDB:3306 (homer db/data)

Status:

* Initial working prototype!
   * needs testing:
     * cron/rotation 
     * kamailio 
     * ui save/load
 
### Pull
```
docker pull qxip/homer-docker
```

### Run
```
docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro lmangani/homer-docker
```

### Test
```
docker run -t -i lmangani/homer-docker
```


