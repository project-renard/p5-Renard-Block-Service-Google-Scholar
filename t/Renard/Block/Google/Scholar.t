#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';
use WWW::Mechanize;
use Web::Scraper;
use CHI;

my $cache = CHI->new( driver => 'File', root_dir => 'cache' );

sub search_response {
	my ($query) = @_;
	my $mech = WWW::Mechanize->new;
	my $response = $mech->get('https://scholar.google.com/');
	my $regular_search = $mech->forms->[0];
	my $advanced_search = $mech->forms->[1];

	my $search_results = $mech->submit_form(
		form_name => $regular_search->attr('name'),
		fields => { q => $query } );
}

subtest "Retrieve results for search query" => sub {
	my $query = 'image segmentation';
	my $search_response = $cache->compute( $query, '10 days', sub {
		search_response($query);
	});

	my $search_scraper = scraper {
		process 'div.gs_r', "entries[]" => scraper {
			process 'h3', 'title' => [
					sub {
						my $title_node = $_->clone;
						my @citation_text_nodes = $title_node->findnodes(q{./span[ @class =~ /gs_ct[uc]/ ]});
						$_->delete for @citation_text_nodes;
						$title_node->as_trimmed_text;
					},
				];
			process 'h3 a', 'links[]' => '@href';
			process 'div.gs_a', 'authors_text' => [
				'TEXT',
				qr/^
					(?<text>
						(?<authors> .*? )
						\s*-\s*
						(?<journal>.*? )
						( ,\s* (?<year>\d{4}))?
						\s*-\s*
						(?<source>.*?)
					)
				$/x  ];
			process 'div.gs_a a', 'authors[]' => scraper {
				process 'a', 'name' => 'TEXT', 'url' => '@href';
			};
			process 'div.gs_rs', 'text' => 'TEXT';
			process '//a[contains(text(), "Cited by")]', 'cited_by' => [ 'TEXT', sub { s/Cited \s+ by \s+ //x } ];
			process 'div.gs_ggs a', 'other_links[]', '@href';
		};
	};

	my $results = $search_scraper->scrape($search_response);

	use DDP; p $results;

	pass;
};

done_testing;
