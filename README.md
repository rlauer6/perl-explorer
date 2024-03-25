# README

This is the `README` file for the `perl-explorer` project.

# Overview

This project implements a Docker container with an Apache handler for
exploring a Perl repository. _Exploring_ consists of:

A UI to:

* Browse code in the source tree
* Display statistics on a Perl module
  * lines, dependencies, subroutines, etc
* Display a Perl module's POD
* Display any markdown found in the project
* Add a POD template to Perl modules
* Display `Perl::Critic` findings for a Perl module
* Tidy Perl modules by using `perltidy`
* Search the repo
* Add TODOs based on `Perl::Critic` findings or other issues

## Motivation

After being involved in several legacy Perl application maintenance
projects it became evident that there needs to be a set of tools that
can be used to explore a repository.  While one could use something
like Visual Studio for performing some of the activities listed in the
feature list of this project, a more comprehensive tool is sometimes
needed.  For example, one measure of the quality of a legacy
application is how well it conforms to best practices.  Using
`Perl::Critic' is a good way to create a baseline for an application
as you attempt to get your bearings and begin maintaining it.

Legacy applications present a multitude of challenges:

* little, no or poor documentation
* low code quality as measured by tools like `Perl::Critic`
* poorly formatted files that do not adhere to any standard
* code organization issues
  * no or misuse of namespaces
  * scripts and modules co-mingled
* difficult to provision or no development, test and staging
  environments
* no build system that checks syntax, installs assets or that checks
  code for adherence to standards
  
`perl-explorer` attempts to help shine some light on these and other
issues with the application.

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

# TODO

# Project TODO

## Build

* [x] Docker container
* [ ] 

## Tree View

* [ ] Help
* [ ] exclude directories
* [ ] include Perl scripts

## Source View
  [ ] subs drop down
  [ ] add TODOs
  [ ] explore use of `ctags`

## Critic View

* [ ] diagnostics
* [ ] 

