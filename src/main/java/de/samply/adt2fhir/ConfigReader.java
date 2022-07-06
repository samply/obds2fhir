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
    public String identifier_system;
    public String mainzelliste_url;
    public String mainzelliste_apikey;
    public String idtype;

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
            this.identifier_system = prop.getProperty("identifier_system");
            this.mainzelliste_url = prop.getProperty("mainzelliste_url");
            this.mainzelliste_apikey = prop.getProperty("mainzelliste_apikey");
            this.idtype = prop.getProperty("idtype");
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
}