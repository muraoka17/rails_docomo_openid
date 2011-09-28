require "openid/store/filesystem"
require "net/https"

class ConsumerController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.xrds { render_xrds }
    end
  end

  def start
    openid_req = consumer.begin("https://i.mydocomo.com/")

    return_to = url_for(:action => "complete", :guid => params[:guid], :only_path => false)
    realm = url_for(:action => "index", :only_path => false)

    if openid_req.send_redirect?(realm, return_to)
      redirect_to(openid_req.redirect_url(realm, return_to))
    else
      render(:text => openid_req.html_markup(realm, return_to, false, {:id => "openid_form"}))
    end
  end

  def complete
    current_url = url_for(:action => "complete", :only_path => false)
    parameters = params.reject{|k, v| request.path_parameters[k]}
    parameters.each {|k,v| parameters[k] = v.tr(" ", "+")}

    openid_resp = consumer.complete(parameters, current_url)
    case openid_resp.status
    when OpenID::Consumer::SUCCESS
      @result = {
        :open_id => openid_resp.message.get_arg(OpenID::OPENID_NS, "identity"),
        :nonce => openid_resp.message.get_arg(OpenID::OPENID_NS, "response_nonce")
      }

      @result.merge!(get_guid) if params[:guid].present?

      render(:action => "complete")
    when OpenID::Consumer::SETUP_NEEDED
      # XXX: immediate モードでの実行は未対応のため行わないはず
      logger.info("[openid_complete] setup needed authentication response")
      redirect_to(:action => "start")
    when OpenID::Consumer::CANCEL
      # XXX: docomo openid ではキャンセルは無い
      logger.info("[openid_complete] cancel authentication response")
      render(:action => "cancel")
    when OpenID::Consumer::FAILURE
      logger.error("[openid_complete] failure authentication response")
      render(:action => "error")
    else
      logger.error("[openid_complete] invalid authentication response: #{openid_resp.status}")
      render(:action => "error")
    end
  end

  private
  def consumer
    if @consumer.nil?
      dir = File.join(Rails.root, "tmp", "cstore")
      store = OpenID::Store::Filesystem.new(dir)
      OpenID::DefaultNegotiator.allowed_types = [["HMAC-SHA256", "DH-SHA256"]]
      @consumer = OpenID::Consumer.new(session, store)
    end

    return @consumer
  end

  def render_xrds
    yadis =<<-YADIS
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns:xrds="xri://$xrds" xmlns:openid="http://openid.net/xmlns/1.0" xmlns="xri://$xrd*($v*2.0)">
<XRD>
<Service priority="0">
<Type>http://specs.openid.net/auth/2.0/return_to</Type>
<URI>#{url_for(:action => "complete", :only_path => false)}</URI>
</Service>
</XRD>
</xrds:XRDS>
    YADIS

    response.headers["content-type"] = "application/xrds+xml"
    render(:text => yadis)
  end

  def get_guid
    http = Net::HTTP.new("i.mydocomo.com", 443)
    http.use_ssl = true
    http.ca_file = Rails.root + "/config/cert.pem"
    #http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.verify_depth = 5
    http.open_timeout = 10
    http.read_timeout = 15

    resp = nil
    http.start do |con|
      resp = con.get(url_for(:controller => "/api/imode",
                             :action => "g-info",
                             :ver => "1.0",   # 値は 1.0 固定
                             :GUID => "",     # 要素名のみ指定、値はセットしない
                             :UA => "",       # 要素名のみ指定、値はセットしない
                             :openid => @result[:open_id],
                             :nonce => @result[:nonce],
                             :skip_relative_url_root => true))
    end

    result = {}
    case resp
    when Net::HTTPSuccess
      result = Hash[*resp.body.chomp.split("\r\n").map{|k| k.split(":", 2)}.flatten]
    else
      logger.error("[get_guid] HTTP status code is #{resp.code}")
    end

    return result
  end
end
