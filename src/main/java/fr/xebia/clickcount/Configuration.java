package fr.xebia.clickcount;

import javax.inject.Singleton;

@Singleton
public class Configuration {

    public final String redisHost;
    public final int redisPort;
    public final int redisConnectionTimeout;  //milliseconds

    public Configuration() {
        redisHost = System.getenv("REDIS_HOST");
        redisPort = Integer.parseInt(System.getenv("REDIS_PORT"));
        // redisConnectionTimeout = System.getenv("REDIS_CONNECTION_TIMEOUT");
        redisConnectionTimeout = 2000;
    }
}
