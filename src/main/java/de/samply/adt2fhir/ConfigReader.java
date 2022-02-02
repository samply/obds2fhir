package de.samply.adt2fhir;

import javax.xml.transform.TransformerException;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.Date;
import java.util.Properties;

public class ConfigReader {
    private static final String PROPERTY_FILE = "common.properties";
    public String file_path;

    public void init() throws IOException {
        try {
            Properties prop = new Properties();
            InputStream inputStream = ConfigReader.class.getClassLoader().getResourceAsStream(PROPERTY_FILE);
            if (inputStream != null) {
                prop.load(inputStream);
            } else {
                throw new FileNotFoundException("property file '" + PROPERTY_FILE + "' not found in resouces");
            }
            this.file_path = prop.getProperty("file_path");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public String getFile_path() {
        return file_path;
    }
}