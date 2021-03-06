
SHELL=/bin/bash
PYTHON=`which python2.7`

CLOSURE_LIBRARY=libs/closure-library/
CLOSURE_COMPILER=libs/closure-compiler.jar
SELENIUM_SERVER=libs/selenium-server.jar

CHROME_EXT_NAME=grooveshark-control
CHROME_EXT_ZIP_ARCHIVE_NAME=$(CHROME_EXT_NAME).zip
CHROME_EXT_JS_DIR=groovesharkControl/javascript/
CHROME_EXT_COFFEE_SOURCES=$(CHROME_EXT_JS_DIR)*/*.coffee
CHROME_EXT_LOCALES_DIR=groovesharkControl/_locales/
CHROME_EXT_COFFEE_LOCALES=$(CHROME_EXT_LOCALES_DIR)*/*.coffee
CHROME_EXT_STYLES_DIR=groovesharkControl/styles/
CHROME_EXT_SCSS_SOURCES=$(CHROME_EXT_STYLES_DIR)*.sass $(CHROME_EXT_STYLES_DIR)*/*.sass

all:
	@echo "make build - Create zip archive for Chrome"
	@echo "make compile - Compile Chrome Extension"
	@echo "make test - Test Chrome Extension"
	@echo "make clean - Clean directory from compiled and building files"
	@echo "make localdev - Init submodules, git-hooks, ..."
	@echo "make install-libs - Install libs for develop"

build: clean compile
	mkdir /tmp/$(CHROME_EXT_NAME)
	cp -r groovesharkControl/* /tmp/$(CHROME_EXT_NAME)/
	find /tmp/$(CHROME_EXT_NAME)/javascript/* -not -name *.min.js -not -name compiled | xargs rm -rf
	find /tmp/$(CHROME_EXT_NAME)/styles/* -not -name *.css | xargs rm -rf
	find /tmp/$(CHROME_EXT_NAME)/_locales/*/* -name *.coffee | xargs rm -rf
	rm /tmp/$(CHROME_EXT_NAME)/manifest.coffee
	cd /tmp; zip -r -q -9 $(CHROME_EXT_ZIP_ARCHIVE_NAME) $(CHROME_EXT_NAME)
	mv /tmp/$(CHROME_EXT_ZIP_ARCHIVE_NAME) $(CHROME_EXT_ZIP_ARCHIVE_NAME)
	rm -rf /tmp/$(CHROME_EXT_NAME)

compile: compile-css compile-jsons compile-coffee compile-mainjs compile-contentscript

compile-css:
	sass --update $(CHROME_EXT_SCSS_SOURCES)

compile-jsons:
	coffee -pb groovesharkControl/manifest.coffee > groovesharkControl/manifest.json
	coffee -cb $(CHROME_EXT_COFFEE_LOCALES)
	for f in `find $(CHROME_EXT_LOCALES_DIR) -name *.js`; do mv $$f $$f'on'; done
	sed -i "s/^(//;s/);$$//" groovesharkControl/*.json $(CHROME_EXT_LOCALES_DIR)*/*.json

compile-coffee:
	coffee -cb $(CHROME_EXT_COFFEE_SOURCES)

compile-mainjs:
	$(PYTHON) $(CLOSURE_LIBRARY)closure/bin/calcdeps.py \
	    --path $(CLOSURE_LIBRARY) \
	    --compiler_jar $(CLOSURE_COMPILER) \
	    --input $(CHROME_EXT_JS_DIR)libs/closure-i18n.js \
	    --input $(CHROME_EXT_JS_DIR)libs/slider.js \
	    --input $(CHROME_EXT_JS_DIR)options/settings.js \
	    --input $(CHROME_EXT_JS_DIR)groovesharkControl/groovesharkControl.js \
	    --input $(CHROME_EXT_JS_DIR)groovesharkControl/viewUpdater.js \
	    --input $(CHROME_EXT_JS_DIR)background/contextMenu.js \
	    --input $(CHROME_EXT_JS_DIR)background/background.js \
	    --input $(CHROME_EXT_JS_DIR)popup/popup.js \
	    --input $(CHROME_EXT_JS_DIR)notification/notification.js \
	    --input $(CHROME_EXT_JS_DIR)options/options.js \
	    --output_mode compiled \
	    > $(CHROME_EXT_JS_DIR)compiled/groovesharkControl.min.js;

compile-contentscript:
	$(PYTHON) $(CLOSURE_LIBRARY)closure/bin/calcdeps.py \
	    --path $(CLOSURE_LIBRARY) \
	    --compiler_jar $(CLOSURE_COMPILER) \
	    --input $(CHROME_EXT_JS_DIR)contentscript/contentscript.js \
	    --output_mode compiled \
	    > $(CHROME_EXT_JS_DIR)compiled/contentscript.min.js;
	$(PYTHON) $(CLOSURE_LIBRARY)closure/bin/calcdeps.py \
	    --path $(CLOSURE_LIBRARY) \
	    --compiler_jar $(CLOSURE_COMPILER) \
	    --input $(CHROME_EXT_JS_DIR)contentscript/shortcut.js \
	    --output_mode compiled \
	    > $(CHROME_EXT_JS_DIR)compiled/shortcut.min.js;

test: start-selenium-server test-compile
	#chromium-browser --temp-profile --allow-file-access-from-files $(CHROME_EXT_JS_DIR)alltests.html
	$(PYTHON) $(CHROME_EXT_JS_DIR)alltests.py

test-compile:
	coffee -cb $(CHROME_EXT_JS_DIR)
	coffee -cb $(CHROME_EXT_COFFEE_SOURCES)
	$(PYTHON) $(CLOSURE_LIBRARY)closure/bin/calcdeps.py \
	    --dep $(CLOSURE_LIBRARY) \
	    --path $(CHROME_EXT_JS_DIR) \
	    --output_mode deps \
	    > $(CHROME_EXT_JS_DIR)test_deps.js;

clean:
	rm -rf /tmp/$(CHROME_EXT_NAME) $(CHROME_EXT_ZIP_ARCHIVE_NAME)
	rm -f groovesharkControl/manifest.json
	find $(CHROME_EXT_LOCALES_DIR) -type f -name *.json | xargs rm -f
	find $(CHROME_EXT_JS_DIR) -type f -name *.js -not path compiled/ | xargs rm -f
	find $(CHROME_EXT_STYLES_DIR) -type f -name *.css | xargs rm -f

localdev: install-git-hooks init-submodules get-selenium-server install-libs

install-git-hooks:
	cp git-hooks/* .git/hooks/
	chmod 755 .git/hooks/

init-submodules:
	git submodule init
	git submodule update

install-libs:
	apt-get install nodejs coffeescript python2.7 libhaml-ruby1.8 chromium-browser openjdk-7-jre
	wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
	python2.7 get-pip.py
	rm get-pip.py
	pip-2.7 install -U selenium

get-selenium-server:
	wget http://selenium.googlecode.com/files/selenium-server-standalone-2.24.1.jar -O $(SELENIUM_SERVER)

start-selenium-server:
	java -jar $(SELENIUM_SERVER) &
	sleep 1
