helpers do
  
  def enforce_admin
    if !current_user.admin?
      halt 403
    end
  end

  def upload(filename, file)
    AWS::S3::Base.establish_connection!(
      :access_key_id     => ENV['ACCESS_KEY_ID'],
      :secret_access_key => ENV['SECRET_ACCESS_KEY']
    )
    AWS::S3::S3Object.store(
      'images/' + filename,
      open(file.path),
      'millwoodonline'
    )
    return filename
  end
  
  def cache(tag,ttl,use_cache,block)
    page = REDIS.get(tag)
    if page and use_cache and !logged_in?
      ttl = REDIS.ttl(tag)
      response.header['redis-ttl'] = ttl.to_s
      response.header['redis'] = 'HIT'
      return page
    else
      page = block.call
      REDIS.setex(tag,ttl,page) if use_cache and !logged_in?
      response.header['redis'] = 'MISS'
      return page 
    end
  end

  def cache_url(ttl=300,use_cache=true,&block)
    cache("url:#{request.url}",ttl,use_cache,block)
  end
  
  def is_cached
    tag = "url:#{request.url}"
    page = REDIS.get(tag)
    if page and !logged_in?
      expires 3600, :public, :must_revalidate
      etag Digest::SHA1.hexdigest(page)
      ttl = 3600 - REDIS.ttl(tag)
      response.header['Age'] = ttl.to_s
      response.header['X-redis'] = 'HIT'
      return page
    end
  end
  
  def set_cache(page)
    if page and !logged_in?
      expires 3600, :public, :must_revalidate
      etag Digest::SHA1.hexdigest(page)
      tag = "url:#{request.url}"
      REDIS.setex(tag, 3600, page)
    else
      cache_control :no_cache
    end
    response.header['X-redis'] = 'MISS'
    return page
  end
end
