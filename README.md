
![homer](http://i.imgur.com/ViXcGAD.png)

# HOMER 5 Docker
http://sipcapture.org

A simple recipe:

* debian/jessie (base image)
* Kamailio:9060 (sipcapture module)
* Apache2/PHP:80 (homer ui/api)
* MySQL/InnoDB:3306 (homer db/data)

Status:

* Initial working prototype - Testing Needed!
 
### Pull latest
```
docker pull qxip/homer-docker
```

### Run latest
```
docker run -tid --name homer5 -p 80:80 -p 9060:9060 lmangani/homer-docker
```

### Local Build & Test
```
git clone https://github.com/lmangani/homer-docker; cd homer-docker
docker build --tag="qxip/homer-docker:local" ./
docker run -t -i lmangani/homer-docker:local
```


