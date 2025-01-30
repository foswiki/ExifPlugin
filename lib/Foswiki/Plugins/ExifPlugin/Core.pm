# Plugin for Foswiki - The Free and Open Source Wiki, https://foswiki.org/
#
# ExifPlugin is Copyright (C) 2023-2025 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::ExifPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Image::ExifTool ();
use MIME::Base64 qw(encode_base64);

use constant TRACE => 0; # toggle me

sub new {
  my $class = shift;

  my $this = bless({@_}, $class);

  return $this;
}

sub finish {
  my $this = shift;

  undef $this->{_exifTool};
}

sub EXIF {
  my ($this, $session, $params, $topic, $web) = @_;

  _writeDebug("called EXIF()");

  my ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($params->{web} || $web, $params->{topic} || $topic);
  return _inlineError("topic not found") unless Foswiki::Func::topicExists($thisWeb, $thisTopic);

  my $attName = $params->{_DEFAULT} || $params->{attachment};
  return _inlineError("no attachment specified") unless $attName;

  ($attName) = Foswiki::Sandbox::sanitizeAttachmentName($attName);
  return _inlineError("attachment not found") unless Foswiki::Func::attachmentExists($thisWeb, $thisTopic, $attName);

  _writeDebug("reading $attName at $thisWeb.$thisTopic");

  return _inlineError("no attachment specified") unless $attName;

  $thisWeb =~ s/\./\//g;
  my $attPath = "$Foswiki::cfg{PubDir}/$thisWeb/$thisTopic/$attName";
  _writeDebug("attPath=$attPath");

  return _inlineError("attachment not found") unless -f $attPath;

  my $coordFormat = $params->{coord_format} // '%+.8f';
  my $info = $this->exifTool->ImageInfo(
    $attPath,
    {
      Duplicates => 1,
      Binary => 1,
      CoordFormat => $coordFormat
    }
  );

  if (Foswiki::Func::isTrue($params->{raw})) {
    my @result = ();
    foreach my $key (sort keys %$info) {
      next if $key =~ /^(Directory|FilePermissions|FileAccessDate|FileInodeChangeDate|FileModifyDate)$/;
      my $val = $info->{$key};
      if (ref $val eq 'ARRAY') {
        $val = join(', ', @$val);
      } elsif (ref $val eq 'SCALAR') {
        $val = encode_base64($val, "");
        $val =~ s/\s+$//;
        $val =~ s/^\s+//;
      }
      $key =~ s/ \((\d+)\)$/_$1/;
      push @result, sprintf("%-24s : %s", $key, $val);
    }
    return "<verbatim>" . join("\n", @result) . "</verbatim>";
  }

  my $result = $params->{format} // '$FileName, $FileSize';

  while (my ($key, $val) = each %$info) {
    next if $key =~ /^(Directory|FilePermissions|FileAccessDate|FileInodeChangeDate|FileModifyDate)$/;
    if (ref $val eq 'ARRAY') {
      $val = join(', ', @$val);
    } elsif (ref $val eq 'SCALAR') {
      $val = encode_base64($val, "");
      $val =~ s/\s+$//;
      $val =~ s/^\s+//;
    }
    $key =~ s/ \((\d+)\)$/_$1/;
    $result =~ s/\$$key\b/$val/g;
  }

  return Foswiki::Func::decodeFormatTokens($result);
}

sub exifTool {
  my $this = shift;

  $this->{_exifTool} = Image::ExifTool->new() unless defined $this->{_exifTool};

  return $this->{_exifTool};
}

sub _inlineError {
  my $msg = shift;
  return "<span class='foswikiAlert'>ERROR: $msg</span>";
}

sub _writeDebug {
  return unless TRACE;

  print STDERR "ExifPlugin::Core - $_[0]\n";
}

1;
