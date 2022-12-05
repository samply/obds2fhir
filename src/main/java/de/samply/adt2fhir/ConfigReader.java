package de.samply.adt2fhir;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class ConfigReader {
    private static final String PROPERTY_FILE = "adt2fhir.properties";
    public String file_path;
    public String store_path;
    public String store_auth;
    public String identifier_system;
    public String mainzelliste_url;
    public String mainzelliste_apikey;
    public String idtype;
    public boolean ssl_certificate_validation;
    public boolean add_departments;

    public void init() throws IOException {
        try {
            Properties prop = new Properties();
            InputStream inputStream =null;
            File file = new File("/etc/samply/"+PROPERTY_FILE);
            if (file.isFile()){
                inputStream =new FileInputStream(file);
            }
            else {
                //no docker, try project configuration
                inputStream = ConfigReader.class.getClassLoader().getResourceAsStream(PROPERTY_FILE);
            }
            if (inputStream != null) {
                prop.load(inputStream);
            }
            this.file_path = prop.getProperty("file_path");
            this.store_path = prop.getProperty("store_path");
            this.store_auth = prop.getProperty("store_auth");
            this.identifier_system = prop.getProperty("identifier_system");
            this.mainzelliste_url = prop.getProperty("mainzelliste_url");
            this.mainzelliste_apikey = prop.getProperty("mainzelliste_apikey");
            this.idtype = prop.getProperty("idtype");
            this.ssl_certificate_validation = Boolean.parseBoolean(prop.getProperty("ssl_certificate_validation"));
            this.add_departments = Boolean.parseBoolean(prop.getProperty("add_departments"));
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public String getFile_path() {
        return file_path;
    }
    public String getStore_path() {
        return store_path;
    }
    public String getStore_auth() {
        return store_auth;
    }
    public String getIdentifier_system() {
        return identifier_system;
    }
    public String getMainzelliste_url() { return mainzelliste_url; }
    public String getMainzelliste_apikey() {
        return mainzelliste_apikey;
    }
    public String getIdtype() {
        return idtype;
    }
    public Boolean getSsl_certificate_validation() {
        return ssl_certificate_validation;
    }
    public Boolean getAdd_departments(){return add_departments;}
}