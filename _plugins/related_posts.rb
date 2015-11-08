require 'rubygems'
require 'singleton'
require 'tokenizer'
require 'fast_stemmer'
require 'stopwords'
require 'pqueue'
require 'nmatrix'
require 'nmatrix/lapacke'

class RelatedPosts
  include Singleton

  def initialize
    @posts = Array.new
    @keywords = Array.new
    @tokenizer = Tokenizer::Tokenizer.new(:en)
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
    @weights = keywords_weights(site.config['related']['weights'] || {})
    related = find_releated(site.config['related']['max_count'],
                            site.config['related']['min_score'],
                            site.config['related']['accuracy'])
    template = Liquid::Template.parse(File.read(File.join(site.config['source'],
                                                site.config['layouts_dir'],
                                                'related.html')))

    @posts.each do |post|
      filename = File.join(site.config['destination'], post[:url])
      rendered = File.read(filename)

      output = template.render('related_posts' => related[post])

      rendered.gsub! '<related-posts />', output
      File.write(filename, rendered)
    end
  end

  private

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

    result.each_with_indices do |_, pi, ki|
      result[pi, ki] = @posts[pi][:content].count(@keywords[ki])
    end

    return result
  end

  def term_frequency
    result = NMatrix.new([@posts.size, @keywords.size], 0.0)

    bag_of_words.each_row do |row|
      max = row.max(1)[0]
      row.each_with_index do |value, ki|
        result[row.offset[0], ki] = (value * @weights[ki]) / max
      end
    end

    return result
  end

  def keywords_weights(weights)
    result = NMatrix.new([@keywords.size], 1.0)

    weights.each do |word, weight|
      keyword = word.to_s.stem.to_sym

      next unless @keywords.include? keyword

      result[@keywords.index(keyword)] = weight
    end

    return result
  end

  def inverse_document_frequency
    result = NMatrix.new([@keywords.size], 0.0)

    bag_of_words.each_column do |column|
      occurences = column.reduce do |m, c|
        m + (c > 0 ? 1.0 : 0.0)
      end

      result[column.offset[1]] = Math.log(column.size / occurences) if occurences > 0
    end

    return result
  end

  def tfidf
    tf = term_frequency
    idf = inverse_document_frequency

    result = NMatrix.new([@posts.size, @keywords.size], 0.0)

    result.each_with_indices do |_, pi, ki|
      result[pi, ki] = tf[pi, ki] * idf[ki]
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

Jekyll::Hooks.register :posts, :pre_render do |post|
  RelatedPosts.instance.add_post(post)
end

Jekyll::Hooks.register :site, :post_write do |site|
  RelatedPosts.instance.build! site
end
