# jekyll-related-posts

Proper related posts plugin for Jekyll - uses document correlation
matrix on TF-IDF (optionally with Latent Semantic Indexing).

# Example

Example is provided at http://jekyll-related-posts.dev.amadeusz.me - posts are
based on
[Reuters-21578](https://archive.ics.uci.edu/ml/datasets/Reuters-21578+Text+Categorization+Collection)
data set.

## Introduction

I am going to try to start blogging, again. Anyway I am studying at
Decision Support Systems Group and I have found document correlation
problem somehow interesting.

For my own purposes I have created related posts Jekyll plugin based on well
known algorithms such as [TFIDF](https://en.wikipedia.org/wiki/Tf–idf)
and [LSI](https://en.wikipedia.org/wiki/Latent_semantic_indexing).

## How to install

I am new to Jekyll - I will try to make installation process easier (I
guess I can create gem for the plugin), but for now it goes as follows:

1. Download this repository.
2. Copy `Gemfile` to your site root directory and run `bundle install`
(it requires lapack libs for linear algebra).
3. Copy `_layouts/related.html` and modify to your needs.
4. Insert `<related-posts />` somewhere in your `_layouts/post.html`
file.
5. Append content of `_config.yml` to your config and customize it to
your needs.
6. Run `jekyll build`, don't forget to blog about the plugin!

## Basis of operation

Each document is
[tokenized](https://en.wikipedia.org/wiki/Tokenization_(lexical_analysis))
and [stemmed](https://en.wikipedia.org/wiki/Stemming), every word found
is treated as keyword for analysis (except for some [stop
words](https://en.wikipedia.org/wiki/Stop_words)). 

TF-IDF matrix for the whole site is calculated (including extra provided 
weights), then if given accuraccy is lower than 1.0, LSI algorithm 
is used to compute new simplified vector space. Document correlation 
matrix is created using dot product of the matrix and its transpose.

For each of the post' related documents are inserted into priority queue
(sorted by score from document correlation matrix), assuming the score
is greater than minimal required score. Selected few bests related posts
are retrieven from the queue.

Liquid template for each post is rendered and `<related-posts />` is
replaced with the outcomes of algorithm.

## Benchmark

I did not benchmark the plugin, however for the dataset given in the
example (containing ~900 documents, ~7000 keywords) rendering time
(including Jekyll hoodoo stuff) is more less 70 seconds (on Xeon, using
750MB RAM). Computations related to this plugin is about 20 seconds
long. It should be noticed that I'm using OpenBLAS and standard LAPACK
distributed with Ubuntu (performance is similar on OS X using builtin
Acccelerate framework).

Unfortunately the plugin is not compatible with Jekyll 3.0 new
incremental builds, even though it requires at least Jekyll 3.0 (for the
plugin hooks).

## Authors

- Amadeusz Juskowiak - juskowiak[at]amadeusz.me
