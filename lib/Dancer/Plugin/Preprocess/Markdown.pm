package Dancer::Plugin::Preprocess::Markdown;

use strict;
use warnings;

# ABSTRACT: Generate HTML content from Markdown files

# VERSION

use Cwd 'abs_path';
use Dancer ':syntax';
use Dancer::Plugin;
use File::Spec::Functions qw(catfile);
use Text::Markdown qw(markdown);

my $settings = {
    save => 0,
    recursive => 0,
    %{plugin_setting()}
};
my $paths;

if (exists $settings->{paths}) {
    $paths = $settings->{paths};
}

my $paths_re = join '|', map { s{^/|/$}{}; quotemeta } keys %$paths;

if ($paths_re ne '') {
    $paths_re = quotemeta('/') . $paths_re;
}

sub _process_markdown_file {
    my $md_file = shift;

    open (my $f, '<', $md_file);
    my $contents;
    {
        local $/;
        $contents = <$f>;
    }
    close($f);

    return markdown($contents);
}

my $handler_defined;

# Postpone setting up the route handler to the time before the first request is
# processed, so that other routes defined in the app will take precedence.
hook on_reset_state => sub {
    return if $handler_defined;

    get qr{($paths_re)/(.*)} => sub {
        my ($path, $file) = splat;

        debug $file;

        $path .= '/';
        my $path_settings;

        for my $path_prefix (keys %$paths) {
            (my $path_prefix_slash = $path_prefix) =~ s{([^/])$}{$1/};

            if (substr($path_prefix_slash, 0, length($path)) eq $path) {
                debug "Matched path: $path_prefix";
                $path_settings = { 
                    save => $settings->{save},
                    recursive => $settings->{recursive},
                    %{$paths->{$path_prefix} || {}}
                };
            }
        }

        # Pass if there was no matching path
        return pass if (!defined $path_settings);

        # Pass if the requested file appears to be in a subdirectory while
        # recursive is off
        return pass if (!$path_settings->{recursive} && $file =~ m{/});

        if (!exists $path_settings->{source_dir}) {
            $path_settings->{source_dir} = path 'md', 'src', split(m{/}, $path);
        }

        # Strip off the ".html" suffix, if present
        $file =~ s/\.html$//;

        my $src_file = path abs_path(setting('appdir')),
            $path_settings->{source_dir}, ($file . '.md');

        if (!-r $src_file) {
            return send_error("Not allowed", 403);
        }

        my $content;

        if ($path_settings->{save}) {
            if (!exists $path_settings->{destination_dir}) {
                $path_settings->{destination_dir} = path 'md', 'dest',
                    split(m{/}, $path);
            }

            my $dest_file = path abs_path(setting('appdir')),
                $path_settings->{destination_dir}, ($file . '.html');

            if (!-f $dest_file ||
                ((stat($dest_file))[9] < (stat($src_file))[9]))
            {
                # Source file is newer than destination file
                $content = _process_markdown_file($src_file);

                open(my $f, '>', $dest_file);
                print {$f} $content;
                close($f);
            }
            else {
                open (my $f, '<', $dest_file);
                {
                    local $/;
                    $content = <$f>;
                }
                close($f);
            }
        }
        else {
            $content = _process_markdown_file($src_file); 
        }

        # TODO: Add support for path-specific layouts
        return (engine 'template')->apply_layout($content);
    };

    $handler_defined = 1;
};

sub preprocess_markdown {
    my (%options) = @_;

    my $contents;
    if (exists $options{file}) {
        open (my $f, '<', $options{file});
        {
            local $/;
            $contents = <$f>;
        }
        close($f);
    }

    return markdown $contents;
}

register 'preprocess_markdown' => \&preprocess_markdown;

register_plugin;

1;

__END__

=head1 SYNOPSIS

    plugins:
      "Preprocess::Markdown":
        save: 1
        paths:
          "/articles":
            source_dir: "src/markdown"
            recursive: 1
            save: 0
          "/":
            save: 1
