# TeSS

**Training eSupport System** using Ruby on Rails.

TeSS is a Rails 5 application.

[![CircleCI](https://circleci.com/gh/nrmay/TeSS/tree/master.svg?style=svg)](https://circleci.com/gh/nrmay/TeSS/tree/master)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/fbe7186d5f2e43e890ec4f5c76445e33)](https://www.codacy.com/gh/nrmay/TeSS/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=nrmay/TeSS&amp;utm_campaign=Badge_Grade)
[![Codacy Badge](https://app.codacy.com/project/badge/Coverage/fbe7186d5f2e43e890ec4f5c76445e33)](https://www.codacy.com/gh/nrmay/TeSS/dashboard?utm_source=github.com&utm_medium=referral&utm_content=nrmay/TeSS&utm_campaign=Badge_Coverage)

## Contents
- [Versions](#versions)
- [Installing the Web Server](#installing-the-web-server)
  - [PostgreSQL Set-up](#postgresql-set-up)
  - [Clone the TeSS repository](#clone-the-tess-repository)
  - [Install Ruby and Gems](#install-ruby-and-gems)
  - [Configuring the TeSS application](#configuring-the-tess-application)
  - [Running the Test Cases](#running-the-test-cases)
  - [Running the Development Environment](#running-the-development-environment)
  - [Running the Production Environment](#running-the-production-environment)
- [Migrate to Unicorn and Nginx](#migrate-to-unicorn-and-nginx)
- [Migrate to Secure Socket Layer (https)](#migrate-to-secure-socket-layer-https)
- [Database backup and restore](#database-backup-and-restore)

## Versions
See the [Change Log](./CHANGE_LOG.md) for details of themes and issues associated with each version.

## Installing the Web Server
Below is an example guide to help you set up TeSS in development mode. 
More comprehensive guides on installing Ruby, Rails, RVM, bundler, postgres, 
etc. are available elsewhere.

These instructions have been tested on the following operating systems:
- Ubuntu 20.04 LTS (focal)

### System Dependencies
TeSS requires the following system packages to be installed:

- RVM
- ImageMagick
- Java JDK
- NodeJS
- PostgreSQL
- Redis
- Yarn

Install the appropriate packages and enable RVM on an Ubuntu-like OS;

    sudo apt-add-repository -y ppa:rael-gc/rvm 
    sudo apt update -y
    sudo apt install git postgresql postgresql-contrib libpq-dev libnode-dev nodejs imagemagick openjdk-8-jre redis-server rvm nginx logrotate yarn
    sudo apt upgrade -y
    sudo usermod -a -G rvm <current user>

... then re-login to enable rvm.

### PostgreSQL Set-up

To set-up PostgreSQL requires user access and turning off the SSL.

Create a database user with ```<username>``` and specified password:

    sudo -i -u postgres
    createuser -Prlds <username>
    exit

#### Check SSL Configuration:

Find the location of the configuration file with the following:

    sudo -u postgres psql -c 'SHOW config_file'

Check the configuration file and if ```ssl=on```:
 - Edit the file and set ```ssl=off```
 - Restart the service: ```sudo service postgresql restart```
   

### Clone the TeSS repository

Clone the source code using git:

    $ git clone https://github.com/dresa-org-au/TeSS.git
    $ cd TeSS

### Install Ruby and Gems
#### Ruby

It is typically recommended to install Ruby with RVM. With RVM, you can specify the version of Ruby you want
installed, plus a whole lot more (e.g. gemsets). Full installation instructions for RVM are [available online](http://rvm.io/rvm/install/).

    rvm install `cat .ruby-version`
    rvm use --create `cat .ruby-version`@`cat .ruby-gemset`

#### Bundler
Bundler provides a consistent environment for Ruby projects by tracking and installing the exact gems and versions that are needed for your Ruby application.

To install it, you can do:

    gem install bundler

Note that program ```gem``` (a package management framework for Ruby called RubyGems) gets installed when you install RVM so you do not have to install it separately.

#### Gems

Once you have Ruby, RVM and bundler installed, from the root folder of the app do:

    bundle install

This will install Rails, as well as any other gem that the TeSS app needs as specified in Gemfile (located in the root folder of the TeSS app).

### Configuring the TeSS application

From the app's root directory, create the configuration files by copying the examples.

    cp config/tess.example.yml config/tess.yml
    cp config/secrets.example.yml config/secrets.
    cp config/sunspot.example.yml config/sunspot.yml
    cp config/ingestion.example.yml config/ingestion.yml

#### Configure TeSS
Edit ```/config/tess.yml``` to override the default configuration. 

Create a new top level element (like ```elixir``` or ```dresa```) and add the override parameters below, such as:

    alternate: &alternate
      contact_email: support@example.com

Then add the alias to the required environment elements, such as:
     
    development:
      <<: *default
      <<: *alternate

#### Configure Secrets
Edit ```config/secrets.yml``` to configure the database name, user and password defined previously.

Edit ```config/secrets.yml``` to configure the app's secret_key_base which you can generate with:

    rake secret

**Note**: ```rake``` is the default task runner for the Ruby on Rails framework. 
If the system has trouble finding the rake executable, 
try prefixing the command with ```bundle exec``` , such as:

    bundle exec rake <task and parameters>

#### Post-configuration tasks

Create the postgresql databases by running the task:

    rake db:create:all

Start the Sidekiq service by running the command: 

    bundle exec sidekiq --daemon

### Running the Test Cases
Set the environment parameter:

    rails db:environment:set RAILS_ENV=test

TeSS uses Apache Solr to power its search and filtering system.

To start solr:

    rake sunspot:solr:start
    rake sunspot:solr:reindex

You can replace *start* with *stop* or *restart* to stop or restart solr. You can use *reindex* to reindex all records.

Prepare the test database and run the test cases:

    rake db:setup
    rake db:test:prepare
    rake test

### Running the Development Environment
Set the environment parameter:

    rails db:environment:set RAILS_ENV=development

To restart solr, run:

    rake sunspot:solr:restart
    rake sunspot:solr:reindex

Prepare the database:

    rake db:setup

And finally, start the server:

    rails server -b 0.0.0.0 &

Check that the server is running by using the following address: 
[http://localhost:3000](http://localhost:3000)
or by executing the following command and reviewing the output:

    curl http://localhost:3000

Also, check the ```log/development.log``` file to see if there are any errors.

#### Setup Administrators

Once you have a local TeSS successfully running, you may want to setup administrative users. To do this register a new account in TeSS through the registration page. Then go to the applications Rails console: 

    rails console [-e <environment>]

And execute the following command, with the appropriate values:

    User.create(username: '<username>', email: '<email>', 
       password: '<passord>', password_confirmation: '<password>', 
       processing_consent: '1', confirmed_at: Time.now(), 
       role: Role.find_by_name('admin'))
     
Exit the console:
    
    exit

The user should now be able to log in and access the administration application.

### Running the Production Environment
Be sure to stop the web server before converting over to the production environment.

Generate the following additional secrets for production environment:
  - secret key: ```rake secret```
  - database user: see [PostgreSQL](#postgresql) set-up      

Set the environment variables in ```/etc/environment```, including:
    
    RAILS_ENV=production
    SECRET_KEY_BASE=<generated secret key> 
    PRODUCTION_DB_USER=<as above>
    PRODUCTION_DB_PASSWORD=<as above>

Set the environment parameter:

    rails db:environment:set RAILS_ENV=development

Set-up the production database:

    unset XDG_RUNTIME_DIR     
    rake db:reset 

... which will do db:drop, db:create, db:schema:load, db:seed.

Restart and reindex Solr:

    rake sunspot:solr:restart
    rake sunspot:solr:reindex

Create an admin user (see above).

The first time and each time a css or js file is updated:

    rake assets:clean
    rake assets:precompile

Restart and check the web server and the ```log/production.log``` file.

## Migrate to Unicorn and Nginx

Make sure the web server is stopped, and stop the following services:

    service stop nginx
    service stop unicor_tess

Apply a fix for the Nginx PId bug:
 
    sudo -E bash
    mkdir /etc/systemd/system/nginx.service.d
    printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d
    systemctl daemon-reload
    exit

Set-up and run the Unicorn service:

    mkdir -p shared/{pids,sockets,log}
    sudo sp unicorn_tess /etc/init.d/unicorn_tess
    sudo chmod 755 /etc/init.d/unicorn_tess
    sudo update-rc.d unicorn_tess defaults
    sudo service unicorn_tess start

Configure Nginx to forward to Unicorn:

Edit the file ```/etc/nginx/sites-available/default``` and replace with the following:

    upstream tess {
       # Path to Unicorn SOCK file, as defined previously
       server unix:/home/ubuntu/TeSS/shared/sockets/unicorn.sock fail_timeout=0;
    }
    
    server {
       listen 80;
       server_name localhost;
       root /home/ubuntu/TeSS/public;
       try_files $uri/index.html $uri @tess; 
       location @tess {
          proxy_pass http://tess;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $http_host;
          proxy_redirect off;
       }
       error_page 500 502 503 504 /500.html;
       client_max_body_size 4G;
       keepalive_timeout 10;
    }

Check the nginx configuration and restart:

    sudo nginx -t
    sudo service nginx restart
    
If there is an error, check the log file: ```/var/log/nginx/error.log```

## Migrate to Secure Socket Layer (Https)

### Using self-signed certificates

Create the self-signed certificate:
   
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 
        -keyout /etc/ssl/private/nginx-selfsigned.key 
        -out /etc/ssl/certs/nginx-selfsigned.crt

Create a strong dhparam

    sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096

Replace the sites available default file:

    cp ssl-nginx.conf /etc/nginx/sites-available/default

Create SSL parameters configuration:
   
    cp ssl-params.conf /etc/nginx/snippets/ssl-params.conf

Create self-signed configuration ```/etc/nginx/snippets/self-signed.conf``` 
with the following contents:

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

Check the nginx configuration and restart:

    sudo nginx -t
    sudo service nginx restart

### Using signed certificates

Download the private key file and save as ```/etc/ssl/private/<private key file>```

Download the ```certificate``` and ```bundle``` files and merge into a new bundle:

    cat <certificate file> <bundle file> >> /etc/ssl/certs/<new bundle file>

Create the signed configuration ```/etc/nginx/snippets/signed.conf```
with the following contents:

    ssl_certificate /etc/ssl/certs/<new bundle file>;
    ssl_certificate_key /etc/ssl/private/<privet key file>;

Replace the sites available default file:

    cp ssl-nginx-signed.conf /etc/nginx/sites-available/default

... and update all occurrences of the ```<url>``` and ```<ip addr>``` parameters 
with the appropriate values for the server.

Check the nginx configuration and restart:

    sudo nginx -t
    sudo service nginx restart

**Note**: sometimes the certificate and key files will not be recognized as such because
the line feeds are not in the correct unix format. In this case, the files need
to be converted to unix format:

    sudo apt install -y dos2unix
    dos2unix /etc/ssl/private/<private key file>
    dos2unix /etc/ssl/certs/<new bundle file>

## Database Backup and Restore

The following scripts can be used to backup and restore the database:

     sh scripts/pgsql_backup.sh

     sh scripts/pgsql_restore.sh

Or, you can run the backup script as follows:

    sh scripts/pgsql_backup.sh tess_user tess_development ./shared/backups --exclude-schema=audit

The parameters are as follows:

1.  user: e.g. *tess_user*
2.  database: e.g. *tess_development*, *tess_production*
3.  backup folder: e.g. ./shared/backups
4.  addtional parameters: e.g. --excluded-schema=audit

Note: sql files are stored with timestamped names as follows:

-  folder/database.YYYYMMDD-HHMMSS.\[schema,data\].sql
-  eg. ~/TeSS/shared/backups/tess_development-20210524-085138.data.sql

And, you can run the restore script as follows:

    sh scripts/pgsql_restore.sh tess_user tess_production ./shared/backups/tess_production.20210524-085138.schema.sql ./shared/backups/tess_production.20210524-085138.data.sql

With the parameters:

1.  user: e.g. *tess_user*
2.  database: e.g. *tess_development*, *tess_production*
3.  schema file: e.g. ./shared/backups/tess_development.20210524-085138.schema.sql
4.  data file: e.g. ./shared/backups/tess_development.20210524-085138.data.sql


Note: these scripts have been adapted from the repository: 
[fabioboris/postgresql-backup-restore-scripts](https://github.com/fabioboris/postgresql-backup-restore-scripts)
-  made available under the MIT License (MIT)
-  Copyright (c) 2013 Fabio Agostinho Boris &lt;fabioboris@gmail.com&gt;
