package PODWebView;
use Dancer ':syntax';

use Dancer::Plugin::Preprocess::Markdown;

use Cwd qw(abs_path);
use Pod::Simple::HTML;

our $VERSION = '0.1';

use Pod::Simple::HTML;
my $p = Pod::Simple::HTML->new;

get '/' => sub {
    template 'index', {
        file_size_limit => config->{app_settings}->{file_size_limit}
    };
};

post '/podhtml' => sub {
    if (request->is_ajax) {
        $p->output_string(\my $html);
        $p->parse_string_document(params->{pod});
        $p->reinit;
        return $html;
    }
    else {
        return error("Not allowed", 403);
    }
};

true;
