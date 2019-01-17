FROM ruby:2.3.1

RUN apt-get update -qq && apt-get -y install sudo

RUN sudo apt-get install -qq -y build-essential nodejs npm libpq-dev git fp-compiler nodejs-legacy libfontconfig1-dev cron

RUN sudo npm install -g phantomjs

ENV APP /farma_alg_reborn

CMD ["/sbin/my_init"]

WORKDIR /tmp
ADD Gemfile /tmp/
ADD Gemfile.lock /tmp
RUN sudo bundle install

RUN mkdir -p $APP

WORKDIR $APP

ENV BUNDLE_PATH /box

COPY . $APP
