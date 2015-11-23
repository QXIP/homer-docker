
![homer](http://i.imgur.com/ViXcGAD.png)

# HOMER 5 Docker
http://sipcapture.org

A simple recipe:

* debian/jessie (base image)
* Kamailio (sipcapture module)
* Apache2/PHP (homer ui/api)
* MySQL/InnoDB (homer db/data)

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



