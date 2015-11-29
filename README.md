
![homer](http://i.imgur.com/ViXcGAD.png)

# HOMER 5 Docker
http://sipcapture.org

A simple recipe to bring up a quick, self-contained Homer5 instance:

* debian/jessie (base image)
* Kamailio4.x:9060 (sipcapture module)
* Apache2/PHP5:80 (homer ui/api)
* MySQL5.6/InnoDB:3306 (homer db/data)

Status:

* Initial working prototype - Testing Needed!
 
### Pull latest
```
docker pull qxip/homer-docker
```

### Run latest
```
docker run -tid --name homer5 -p 80:80 -p 9060:9060 qxip/homer-docker
```

### Local Build & Test
```
git clone https://github.com/qxip/homer-docker; cd homer-docker
docker build --tag="qxip/homer-docker:local" ./
docker run -t -i qxip/homer-docker:local
```


