require 'rubygems'
require 'sequel'
require 'fileutils'

# NOTE: This converter requires Sequel and the MySQL gems.
# The MySQL gem can be difficult to install on OS X. Once you have MySQL
# installed, running the following commands should work:
# $ sudo gem install sequel
# $ sudo gem install mysql -- --with-mysql-config=/usr/local/mysql/bin/mysql_config

module Jekyll
  module WordPress

    # Reads a MySQL database via Sequel and creates a post file for each
    # post in wp_posts that has post_status = 'publish'.
    # This restriction is made because 'draft' posts are not guaranteed to
    # have valid dates.
    POSTS_QUERY = "select post_title, post_name, post_date, post_content, post_excerpt, ID, guid from wp_posts where post_status = 'publish' and post_type = 'post'"
    # Wordpress stores both tags and categories in wp_terms table and
    # wp_term_taxonomy table determines whether term is tag or category.
    # Wp_term_relationships table maps those taxonomy items to actual posts.
    TERMS_QUERY = "SELECT wp_terms.name FROM wp_terms, wp_term_taxonomy INNER JOIN wp_term_relationships ON (wp_term_taxonomy.term_taxonomy_id=wp_term_relationships.term_taxonomy_id) WHERE ((wp_term_relationships.object_id = %d AND wp_terms.term_id = wp_term_taxonomy.term_id AND wp_term_taxonomy.taxonomy = '%s'))"

    def self.process(dbname, user, pass, host = 'localhost')
      db = Sequel.mysql(dbname, :user => user, :password => pass, :host => host)

      FileUtils.mkdir_p "_posts"

      db[POSTS_QUERY].each do |post|
        # Get required fields and construct Jekyll compatible name
        title = post[:post_title]
        slug = post[:post_name]
        date = post[:post_date]
        content = post[:post_content]
        name = "%02d-%02d-%02d-%s.markdown" % [date.year, date.month, date.day,
                                               slug]
        tags = db[TERMS_QUERY % [post[:ID],'post_tag']].map{|t|t[:name]}
        categories = db[TERMS_QUERY % [post[:ID],'category']].map{|t|t[:name]}

        # Get the relevant fields as a hash, delete empty fields and convert
        # to YAML for the header
        data = {
           'layout' => 'post',
           'title' => title.to_s,
           'excerpt' => post[:post_excerpt].to_s,
           'wordpress_id' => post[:ID],
           'wordpress_url' => post[:guid],
           'tags' => tags,
           'categories' => categories
         }.delete_if { |k,v| v.nil? || v == '' || v == []}.to_yaml

        # Write out the data and content to file
        File.open("_posts/#{name}", "w") do |f|
          f.puts data
          f.puts "---"
          f.puts content
        end
      end

    end
  end
end
