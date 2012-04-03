CC=g++
CFLAGS=-c -Wall
LDFLAGS=


all:
    # Create cgi-bin directory if not already present        
	mkdir -p cgi-bin
	$(CC) -o cgi-bin/dem_extractor.cgi dem_extractor.cpp
    # Change permissions so Apache's cool with running cgi
	chmod -R 711 cgi-bin
    