package Apache::Wrapper;

#---------------------------------------------------------------------
#
# usage: PerlHandler Apache::Wrapper
#        PerlSetVar  TEMPLATE "/templ.html" # relative to server root
#        PerlSetVar  REPLACE  "|"              # character or string 
#                                                defaults to "|"
#        PerlSetVar  Filter On                 # optional - will work
#                                                within Apache::Filter
#---------------------------------------------------------------------

use 5.004;
use mod_perl 1.21;
use Apache::Constants qw( OK DECLINED SERVER_ERROR );
use Apache::File;
use Apache::Log;
use strict;

$Apache::Wrapper::VERSION = '0.02';

# set debug level
#  0 - messages at info or debug log levels
#  1 - verbose output at info or debug log levels
$Apache::Wrapper::DEBUG = 1;

sub handler {
#---------------------------------------------------------------------
# initialize request object and variables
#---------------------------------------------------------------------
  
  my $r         = shift;
  my $log       = $r->server->log;
  my $template  = $r->server_root_relative . $r->dir_config('TEMPLATE');

  my $replace   = $r->dir_config('REPLACE') || "|";

  # make Apache::Filter aware using the 'Filter' 
  # perl variable in httpd.conf
  my $filter    = 1 ? $r->dir_config('Filter') =~ m/On/i : 0;

#---------------------------------------------------------------------
# do some preliminary stuff...
#---------------------------------------------------------------------

  $log->info("Using Apache::Wrapper");

  unless ($r->content_type eq 'text/html') {
    $log->info("\trequest is not for an html document - skipping...") 
      if $Apache::Wrapper::DEBUG;
    $log->info("Exiting Apache::Wrapper");  
    return DECLINED; 
  }
 
#---------------------------------------------------------------------
# wrap the template around the requested file...
#---------------------------------------------------------------------
  
  $log->info("\tlooking for \'$replace\' in template $template") 
    if $Apache::Wrapper::DEBUG;

  # open the template handle
  my $tph = Apache::File->new($template);

  unless ($tph) {
    $log->error("\tcannot open template! $!");
    $log->info("Exiting Apache::Wrapper");  
    return SERVER_ERROR;
  }

  # open the request handle
  my $rqh;

  if ($filter) {
    $log->info("\tgetting input from Apache::File") 
      if $Apache::Wrapper::DEBUG;
    $rqh = $r->filter_input;
  } else {
    $log->info("\tgetting input from requested uri")
      if $Apache::Wrapper::DEBUG;
    $rqh = Apache::File->new($r->filename);
  }

  unless ($rqh) {
    $log->warn("\tcannot open request! $!");
    $log->info("Exiting Apache::Wrapper");  
    return DECLINED;
  }

  # output
  while (<$tph>) {

    if (/\Q$replace/) {
      $log->info("\t\'$replace\' found - replacing with request") 
        if $Apache::Wrapper::DEBUG;  

      my ($left, $right) = split /\Q$replace/;
  
      # calling $r->print circumvents Apache::Filter, so just use print
      print $left;            # output the left side of substitution

      if ($filter) {
        while(<$rqh>) {
          print $_;           # output the requested file line by line
        }
      } else {                # if not using Apache::Filter, just dump 
        $r->send_fd($rqh);    # the file for performance improvement
      }

      print $right;           # ouptut the right side of substitution
    }
    else {
      print $_;               # print each template line
    }
  }
 
#---------------------------------------------------------------------
# wrap up...
#---------------------------------------------------------------------

   $log->info("Exiting Apache::Wrapper");

   return OK;
}

1;
__END__

=head1 NAME

Apache::Wrapper - a simple framework for creating uniform, template 
                  driven content.

=head1 SYNOPSIS

  httpd.conf:

  <Location /someplace>
     SetHandler perl-script
     PerlHandler Apache::Wrapper

     PerlSetVar  TEMPLATE "templates/format1.html"
     PerlSetVar  REPLACE "the content goes here"
  </Location>  

  Apache::Wrapper is Filter aware, meaning that it can be used within 
  an Apache::Filter framework without modification.  Just include the
  directive
  
  PerlSetVar Filter On

  and modify the PerlHandler directive accordingly...

=head1 DESCRIPTION

  Apache::Wrapper provides a simple way to insert content within an
  established template for uniform content delivery.  While the end
  result is similar toApache::Sandwich, Apache::Wrapper offers several
  advantages.

  It does not use separate header and footer files, easing the pain of
  maintaining syntactically correct HTML in seperate files.

  It is Apache::Filter aware, thus it can both accept content from
  other content handlers as well as pass its changes on to others
  later in the chain.

=head1 EXAMPLE

  /usr/local/apache/templates/format1.html:

   <html>
        <head><title>your template</title></head>
                <title>your template</title>
        <body bgcolor="#778899">
                some headers, banners, whatever...
                <p>
   the content goes here
                </p>
                <p>some footers, modification dates, whatever...
        </body>
   </html> 


  httpd.conf:

  PerlModule Apache::Filter

  <Location /someplace>
     SetHandler perl-script
     PerlHandler Apache::Wrapper Custom::SomeOtherHandler

     PerlSetVar  TEMPLATE "templates/format1.html"
     PerlSetVar  REPLACE "the content goes here"
     PerlSetVar  Filter On
  </Location>

  Now, a request to http://localhost/someplace/foo.html will insert
  the contents of foo.html in place of "the content goes here" in the
  format1.html template and pass those results to 
  Custom::SomeOtherHandler.  The result is a nice and tidy way to 
  control any custom headers, footers, background colors or images,
  in a single html file.

=head1 NOTES

  TEMPLATE is relative to the ServerRoot - this may change in future 
  releases, depending on demand.

  REPLACE defaults to "|", though it may be any character or string
  you like - metacharacters are disabled in the search, so sorry, no 
  regex for now... 
 
  Verbose debugging is enabled by setting $Apache::Wrapper::DEBUG=1
  or greater.  To turn off all debug information, set your apache 
  LogLevel above info level.

  This is alpha software, and as such has not been tested on multiple
  platforms or environments.  It requires PERL_LOG_API=1, 
  PERL_FILE_API=1, and maybe other hooks to function properly.

=head1 FEATURES/BUGS

  If Apache::Wrapper finds more than one match for REPLACE in the
  template, it will insert the request for the first occurrence only.
  All other replacement strings will just be stripped from the 
  template.

  Currently, Apache::Wrapper will return DECLINED if the content-type
  of the request is not 'text/html'.

=head1 SEE ALSO

  perl(1), mod_perl(3), Apache(3), Apache::Filter(3)

=head1 AUTHOR

  Geoffrey Young <geoff@cpan.org>

=head1 COPYRIGHT

  Copyright 2000 Geoffrey Young - all rights reserved.

  This library is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
