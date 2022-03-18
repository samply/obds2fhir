package de.samply.adt2fhir;

import java.io.*;
import java.util.Properties;

public class ConfigReader {
    private static final String PROPERTY_FILE = "adt2fhir.properties";
    public String file_path;
    public String store_path;

    public void init() throws IOException {
        try {
            Properties prop = new Properties();
            InputStream inputStream =null;
            //try loading docker configuration
            //("adt2fhir.properties");
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
            } else {
                throw new FileNotFoundException("property file '" + PROPERTY_FILE + "' not found in resouces");
            }
            this.file_path = prop.getProperty("file_path");
            this.store_path = prop.getProperty("store_path");
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
}