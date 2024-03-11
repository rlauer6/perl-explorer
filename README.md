# README

This is the `README` file for the `perl-explorer` project.

# TODO

# Project TODO

## Build

* [ ] Docker container

## Configuration

* [ ] move to separate directory, install in more appropriate location
      under site tree
* [ ] UI

## Tree View

* [ ] Help
* [ ] exclude directories
* [ ] multiple repos?

## Source View
  [ ] subs drop down
  [ ] add TODOs
  [ ] explore use of `ctags`

## Critic View

* [ ] diagnostics
* [ ] 

# Overview

This project implements an Apache handler for exploring a Perl
repository. Exploring consists of:

Providing a UI to:

* Browse code in the source tree
* Display some statistics on a Perl module
  * lines, dependencies, subroutines, etc
* Display a Perl module's POD
* Add a POD template to Perl modules
* Display `perlcritic` finding for a Perl module
* Tidy Perl modules by using `perltidy`


# Custom Container

```
yum install -y gcc gcc-c++ libtidyp libtidyp-devel source-highlight source-highlight-devel
ln -s /usr/lib64/libboost_regex.so.1.53.0 /usr/lib64/libboost_regex.so

cpanm -n -v \
  Syntax::SourceHighlight \
  Perl::Tidy \
  HTML::Tidy \
  Template \
  Perl::Critic::Policy::Community::PreferredAlternatives \
  Module::ScanDeps::Static
  
```
