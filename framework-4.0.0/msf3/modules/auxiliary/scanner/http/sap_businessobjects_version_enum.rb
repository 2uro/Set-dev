##
# $Id: sap_businessobjects_version_enum.rb 14124 2011-10-31 16:39:03Z sinn3r $
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##


require 'msf/core'


class Metasploit3 < Msf::Auxiliary

	include Msf::Exploit::Remote::HttpClient
	include Msf::Auxiliary::Report
	include Msf::Auxiliary::Scanner

	def initialize
		super(
			'Name'		   => 'SAP BusinessObjects Version Detection',
			'Version'		=> '$Revision: 14124 $',
			'Description'	=> 'This module simply attempts to identify the version of SAP BusinessObjects.',
			'References'  =>
				[
					# General
					[ 'URL', 'http://spl0it.org/files/talks/source_barcelona10/Hacking%20SAP%20BusinessObjects.pdf' ]
				],
			'Author'		 => [ 'Joshua Abraham <jabra[at]rapid7.com>' ],
			'License'		=> MSF_LICENSE
		)

		register_options(
			[
				Opt::RPORT(8080),
				OptString.new('URI', [false, 'Path to the SAP BusinessObjects Axis2', '/dswsbobje']),
			], self.class)
		register_autofilter_ports([ 8080 ])
		deregister_options('RHOST')
	end

	def rport
		datastore['RPORT']
	end

	def run_host(ip)
		res = send_request_cgi({
			'uri'	 => "/#{datastore['URI']}/services/listServices",
			'method'  => 'GET',
				'headers' => {
					'User-Agent' => datastore['UserAgent']
				}

		}, 25)
		return if not res or res.code != 200

		enum_version(ip)
	end

	def enum_version(rhost)
		verbose = datastore['VERBOSE']
		print_status("Identifying SAP BusinessObjects on #{rhost}:#{rport}")
		success = false
		soapenv='http://schemas.xmlsoap.org/soap/envelope/'
		xmlns='http://session.dsws.businessobjects.com/2007/06/01'
		xsi='http://www.w3.org/2001/XMLSchema-instance'

		data = '<?xml version="1.0" encoding="utf-8"?>' + "\r\n"
		data << '<soapenv:Envelope xmlns:soapenv="' +  soapenv + '"  xmlns:ns="' + xmlns + '">' + "\r\n"
		data << '<soapenv:Header/>' + "\r\n"
		data << '<soapenv:Body>' + "\r\n"
		data << '<ns:getVersion/>' + "\r\n"
		data << '</soapenv:Body>' + "\r\n"
		data << '</soapenv:Envelope>' + "\r\n\r\n"

		begin
			res = send_request_raw({
				'uri'		  => "/#{datastore['URI']}/services/Session",
				'method'	   => 'POST',
				'data'	  => data,
				'headers' =>
					{
						'Content-Length' => data.length,
						'SOAPAction'	=> '"' + 'http://session.dsws.businessobjects.com/2007/06/01/getVersion' + '"',
						'Content-Type'  => 'text/xml; charset=UTF-8',
					}
			}, 15)

			if res.code == 200
				case res.body
				when nil
					# Nothing
				when /<Version xmlns=".*">(.*)<\/Version><\/getVersionResponse>/
					version = "#{$1}"
					success = true
				end
			end

		rescue ::Rex::ConnectionError
			print_error("[SAP BusinessObjects] Unable to attempt authentication")
			return :abort
		end

		if success
			print_good("[SAP BusinessObjects] Version: #{version}")
			return
		else
			print_error("[SAP BusinessObjects] failed to identify version")
			return
		end
	end
end

