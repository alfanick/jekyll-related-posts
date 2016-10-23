# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "jekyll-related-posts"
  spec.version       = "0.1.2"
  spec.authors       = ["Amadeusz Juskowiak"]
  spec.email         = ["juskowiak@amadeusz.me"]
  spec.summary       = %q{Proper related posts plugin for Jekyll - uses document correlation matrix on TF-IDF (optionally with Latent Semantic Indexing).}
  spec.description   = %q{Proper related posts plugin for Jekyll - uses document correlation matrix on TF-IDF (optionally with Latent Semantic Indexing).

Each document is tokenized and stemmed, every word found is treated as keyword for analysis (except for some stop words).

TF-IDF matrix for the whole site is calculated (including extra provided weights), then if given accuraccy is lower than 1.0, LSI algorithm is used to compute new simplified vector space. Document correlation matrix is created using dot product of the matrix and its transpose.

For each of the post' related documents are inserted into priority queue (sorted by score from document correlation matrix), assuming the score is greater than minimal required score. Selected few bests related posts are retrieven from the queue.

Liquid template for each post is rendered and <related-posts /> is replaced with the outcomes of algorithm.}
  spec.homepage      = "https://github.com/alfanick/jekyll-related-posts"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"

	spec.add_runtime_dependency "jekyll", "~> 3.0"
  spec.add_runtime_dependency "liquid", "~> 3.0"
  spec.add_runtime_dependency "tokenizer", "~> 0.3"
  spec.add_runtime_dependency "stopwords-filter", "~> 0.3"
  spec.add_runtime_dependency "fast-stemmer", "~> 1.0"
  spec.add_runtime_dependency "pqueue", "~> 2.1"
  spec.add_runtime_dependency "nmatrix", "~> 0.2"
  spec.add_runtime_dependency "nmatrix-lapacke", "~> 0.2"
end
