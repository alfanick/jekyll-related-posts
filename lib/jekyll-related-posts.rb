require 'rubygems'
require 'jekyll'
require 'singleton'
require 'tokenizer'
require 'yaml'
require 'liquid'
require 'fast_stemmer'
require 'stopwords'
require 'pqueue'
require 'nmatrix'
require 'nmatrix/lapacke'

module Amadeusz
module Jekyll
  class RelatedPosts
    include Singleton

    def initialize
      @posts = Array.new
      @keywords = Array.new
      @tokenizer = Tokenizer::WhitespaceTokenizer.new(:en)
      @stopwords_filter = Stopwords::Snowball::Filter.new('en')
    end

    def add_post(post)
      post = {
        url: post.url,
        title: post.data['title'].dup,
        content: (stem(post.content) + stem(post.data['title']))
      }

      @posts << post
      @keywords += post[:content]
      @keywords.uniq!
    end

    def build!(site)
      conf = config(site)
      @weights = keywords_weights(conf['weights'])
      related = find_releated(conf['max_count'], conf['min_score'], conf['accuracy'])
      template = Liquid::Template.parse(File.read(template_path(site)))

      @posts.each do |post|
        filename = File.join(site.config['destination'], post[:url])
        filename = File.join(filename, 'index.html') if File.directory? filename
        rendered = File.read(filename)

        output = template.render('related_posts' => related[post])

        rendered.gsub! '<related-posts />', output
        File.write(filename, rendered)
      end
    end

    private

    def config(site)
      builtin_file = File.join(File.absolute_path(File.dirname(__FILE__)), '_config.yml')
      defaults = YAML.load_file(builtin_file)

      defaults['related'].merge(site.config['related'] || {})
    end

    def template_path(site)
      site_file = File.join(site.config['source'], site.config['layouts_dir'], 'related.html')
      builtin_file = File.join(File.absolute_path(File.dirname(__FILE__)), 'related.html')

      if File.exist? site_file
        site_file
      else
        builtin_file
      end
    end

    def find_releated(count = 5, min_score = -10.0, accuracy = 1.0)
      dc = document_correleation(accuracy)
      result = Hash.new
      count = [count, @posts.size].min

      @posts.each_with_index do |post, index|
        queue = PQueue.new(dc.row(index).each_with_index.select{|s,_| s>=min_score}) do |a, b|
          a[0] > b[0]
        end

        result[post] = []
        count.times do
          score, id = queue.pop
          break unless score
          begin
            result[post] << {
              'score' => score,
              'url' => @posts[id][:url],
              'title' => @posts[id][:title]
            }
          rescue
            break
          end
        end
      end

      return result
    end

    def lsi(matrix, accuracy)
      degree = (@keywords.size * accuracy - 1).floor
      u, sigma, vt = matrix.transpose.gesdd

      u2 = u.slice(0..degree, 0..degree)
      sigma_d = NMatrix.zeros([degree+1, @posts.size])
      sigma.each_with_indices do |v, i, j|
        break if i > degree
        sigma_d[i, i] = v
      end

      return u2.dot(sigma_d).dot(vt).transpose
    end

    def document_correleation(accuracy = 1.0)
      if accuracy == 1.0
        scores = tfidf
      else
        scores = lsi(tfidf, accuracy)
      end

      result = scores.dot(scores.transpose)

      result.each_with_indices do |_, u, v|
        if u != v
          result[u, v] /= (result[u, u] + result[v, v] - result[u, v])
        else
          result[u, v] = 0.0
        end
      end

      return result
    end

    def bag_of_words
      result = NMatrix.new([@posts.size, @keywords.size], 0.0)
      @max = NMatrix.new([@posts.size], 0.0)

      result.each_with_indices do |_, pi, ki|
        result[pi, ki] = @posts[pi][:content].count(@keywords[ki])

        if result[pi, ki] > @max[pi]
          @max[pi] = result[pi, ki]
        end
      end

      @bag_of_words = result.dup
      return result
    end

    def term_frequency
      result = bag_of_words

      result.rows.times do |r|
        result[r, 0..-1] *= @weights
        result[r, 0..-1] /= @max[r]
      end

      return result
    end

    def keywords_weights(weights)
      result = NMatrix.new([1, @keywords.size], 1.0)

      weights.each do |word, weight|
        keyword = word.to_s.stem.to_sym

        next unless @keywords.include? keyword

        result[0, @keywords.index(keyword)] = weight
      end

      return result
    end

    def inverse_document_frequency
      result = NMatrix.new([1, @keywords.size], 0.0)

      @bag_of_words.each_column do |column|
        occurences = column.reduce do |m, c|
          m + (c > 0 ? 1.0 : 0.0)
        end

        result[0, column.offset[1]] = Math.log(column.size / occurences) if occurences > 0
      end

      return result
    end

    def tfidf
      result = term_frequency
      idf = inverse_document_frequency

      result.rows.times do |r|
        result[r, 0..-1] *= idf
      end

      return result
    end

    def stem(data)
      tokenized = @tokenizer.tokenize(data.gsub(/[^a-z \t'_\-\n.,+]/i, '')).map(&:downcase)
      filtered = @stopwords_filter.filter(tokenized)
      stemmed = filtered.map(&:stem).select{|s| not s.empty?}.map(&:to_sym)

      return stemmed
    end
  end
end
end

Jekyll::Hooks.register :posts, :pre_render do |post|
  Amadeusz::Jekyll::RelatedPosts.instance.add_post(post)
end

Jekyll::Hooks.register :site, :post_write do |site|
  Amadeusz::Jekyll::RelatedPosts.instance.build! site
end
