# Multiple Solr on Torquebox/Jboss/Wildfly
The following are notes for allowing multiple solr instances to be deployed and undeployed on a single torquebox instance.  

## The problem is SOLR_HOME
The problem is that each solr instance needs to have the path to SOLR_HOME configured. This need to configure solr.solr.home for each developer & their application is the pain point for multiple solrs.  Since these solr instance will live within the directory of each project under /umich, each SOLR_HOME should point to /path/to/dev/project/umich/solr.  The conventional way of doing this is to set the java options using -D at runtime or to take apart the war file and modify web.xml.  Neither of these options is appealing.  We would like to be able to configure this system option at deploy time without having to modify the .war file.

On tomcat it is possible to set the solr home directory via JNDI and this may allow us to do this at deploy time per application.  It might be possilbe to do this under torquebox/jboss as well.

### Config directory of application root (*Not Workable*)

https://issues.jboss.org/browse/TORQUE-9
  RAILS_ROOT/config/jboss-web.xml
  The jboss-web.xml in the config directory of the deployed application may be sufficient.

for the tomcat reference see configuring solr home with jndi:
  https://wiki.apache.org/solr/SolrTomcat
```
  <Context docBase="/some/path/solr.war" debug="0" crossContext="true" >
     <Environment name="solr/home" type="java.lang.String" value="/my/solr/home" override="true" />
  </Context>
```

For Jboss, the relevant documentation is here:
http://docs.jboss.org/jbossweb/3.0.x/jndi-resources-howto.html

This line of investigation will not work for the solr.war deployment as it will not hava appliction path to a directory that could contain config/jboss-web.xml.  Instead, it's deployment descriptor will simply point to the /path/to/solr.war.  The config will be read from the contents of that archive.  We would need to override those configuration specifications in the deployment descriptor, but this might not be possible.

### property-service.xml (*Not Workable*)

Might it be possible to do the config at deploy time using properties-service.xml?  Where is this file located and when is it read?

The property-service.xml and all the other application config files for Jboss are listed to live inside the war and ear archives.  Unpackaging, modifying, and repackaging these archives multiple times during the development cycle seem inelegant and adds a significant amount of complexity.

The file properties-service.xml shows up in the deployment directory of the application.  For jboss, deploying a .war file should result in a deployment directory that is essentially the unzipped .war file.  Might it be possible to skip having jboss unpackage the .war file, and do it ahead of time?  Instead of having solr.war have a the resulting directory from solr.war to point to?  That would permit the modification of properties-service.xml or the web.xml prior to deploy time.

### Context Fragments (*Not Workable*)

Setting up multiple solr instances side by side on tomcat is accomlished via context fragments.  These snippets of xml config override or augment the internal configuration within a webapp (called a context in tomcat).  This would **not** require knowing the paths to the solr.war files before starting the server. This method permits adding those paths to the server conf such that it could configure the jndi for each at deploy time.

  e.g. from https://wiki.apache.org/solr/SolrTomcat#Multiple_Solr_Webapps 
```
  $ cat /tomcat55/conf/Catalina/localhost/solr1.xml
  <Context docBase="/some/path/solr.war" debug="0" crossContext="true" >
     <Environment name="solr/home" type="java.lang.String" value="/some/path/solr1home" override="true" />
  </Context>

  $ cat /tomcat55/conf/Catalina/localhost/solr2.xml
  <Context docBase="f:/solr.war" debug="0" crossContext="true" >
     <Environment name="solr/home" type="java.lang.String" value="/some/path/solr2home" override="true" />
  </Context>
```

Found some more information about tomcat conf at: https://wiki.apache.org/solr/SolrTomcat.  It appears that Tomcat will pick up changes made in this directory dynamically, and remove files/symlinks as applications are undeployed.  This is potentially good news assuming that the torquebox deploy operation doesn't over write a file or symlink we write there prior to deployment.
 
  Create a Tomcat Context fragment to point docBase to the $SOLR_HOME/solr.war file and solr/home to $SOLR_HOME:
```
  <?xml version="1.0" encoding="utf-8"?>
  <Context docBase="/opt/solr/example/solr/solr.war" debug="0" crossContext="true">
    <Environment name="solr/home" type="java.lang.String" value="/opt/solr/example/solr" override="true"/>
  </Context>
  Symlink or place the file in $CATALINA_HOME/conf/Catalina/localhost/solr-example.xml, where Tomcat will automatically pick it up. Tomcat deletes the file on undeploy (which happens automatically if the configuration is invalid).
```
  Repeat the above steps with different installation directories to run multiple instances of Solr side-by-side.

The tomcat context fragment approach might work for torquebox which is dependant on jboss which is a fork of tomcat.  The additional step of creating a symlink in $CATALINA_HOME/conf/Catalina/<host>/solr.xml to the appropriate file in the applications /umich directory should work if jboss has an equivalent functionality or setup.  Where is the conf/Catalina equivalent for jboss?

  **There doesn't appear to be an equivalent place or functionality in JBoss/Wildfly to use context fragments. There does not appear to be any external configuration of this sort supported in JBoss.  Shame.**


### Exploded Solr WAR deployment (*Possible Solution*)

Deploying exploded WAR files might be the best option.  Jboss default configureation and documentation suggests autodeploy of exploded archives be turned off.  This is fine for our setup since we're doing the deploy manually by touching the .dodeploy status file anyway.  The exploded war file should be copied to uniquename-solr.war in the torquebox deployment directory.  Then uniquename-solr.war.dodeploy can be touched and the application server should do it's thing.

For this solution, we would explode the solr.war file in the hydra-jetty download.  The "unzip" operation would copy the contents to /umich instead of /jetty under the application directory as usual, but also modify the web.xml or add jboss-web.xml into the exploded solr directory.  This still seems hackish, but should work for now until a method to modify the context configuration at deploy time for Jboss or Wildfly.

### JNDI Config for Application Server (_Pending_)

There may be a solution available here since each solr instance would be prefixed with the uniquename of the developer.  It might be possible to configure the app server in such a way that could be configured or resolved at deploy time.  This avenue seems more complex, but it may be more modular.  Let the application server worry about where solr.home is when the application attempts to resolve that reference.
