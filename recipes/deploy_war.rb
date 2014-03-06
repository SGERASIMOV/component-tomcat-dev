#
#Recipe will deploy war to tomcat
#

execute "wait tomcat" do
  command "sleep 30"
  action :nothing
end

service "tomcat#{node["tomcat"]["base_version"]}" do
  supports :restart => false, :status => true
  action :stop
  notifies :run, "execute[wait tomcat]", :immediately
end

#download war file
require 'uri'

if ( node['tomcat-component']['war_uri'].start_with?('http', 'ftp') )
  uri = URI.parse(node['tomcat-component']['war_uri'])
  file_name = File.basename(uri.path)
  app_name = file_name[0...-4]

  remote_file "/tmp/#{file_name}" do
    source node['tomcat-component']['war_uri']
  end
  
  file_path = "/tmp/#{file_name}"
  
elsif ( node['tomcat-component']['war_uri'].start_with?('file') )
  url = node['tomcat-component']['war_uri']
  file_path = URI.parse(url).path
  file_name = File.basename(file_path)
  app_name = File.basename(file_name)[0...-4]
end

#cleanup tomcat before deploy
file "#{node['tomcat']['webapp_dir']}/#{file_name}" do
  action :delete
end

file "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
  action :delete
end

directory "#{node['tomcat']['webapp_dir']}/#{app_name}" do
  recursive true
  action :delete
end

#deploy war
bash "copy #{file_path} to tomcat" do
  user "root"
  code <<-EOH
  cp -fr #{file_path} #{node['tomcat']['webapp_dir']}/
  chmod 644 #{node['tomcat']['webapp_dir']}/#{file_name}
  chown #{node['tomcat']['user']}:#{node['tomcat']['group']} #{node['tomcat']['webapp_dir']}/#{file_name}
  EOH
end

#create context file
if (! node['tomcat-component']['context'].nil?) 
  template "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
    owner node["tomcat"]["user"]
    group node["tomcat"]["group"]
    source "context.xml.erb"
    variables({
      :context_attrs => node["tomcat-component"]["context"].to_hash.fetch("context_attrs", {}),
      :context_nodes => node["tomcat-component"]["context"].to_hash.fetch("context_nodes", [])
    })
    notifies :start, "service[tomcat#{node["tomcat"]["base_version"]}]", :immediately
  end
end

