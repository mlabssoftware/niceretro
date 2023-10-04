# Niceretro

A friendly application to manage agile retrospectives easily.
With Niceretro, your team can share Positive and Negative points lived on last sprint,
as point any team's doubts.


## Requisites

* Ruby 2.3
* PostgreSQL 11.5


## Installation
* apt install bundler || apt install bundler -v 1.17.1
* bundle install || bundle _1.17_1_ install
* rake db:create
* rake db:migrate
* rake db:seed

## Environment variables

#### Database
* DB_HOST - database host
* DB_USER - database user name
* DB_PASSWORD - database password
* DB_DATABASE - database name

#### System access
* NICE_USER - system user name
* NICE_PASSWORD - system user password

# LICENSE

This project is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT)
