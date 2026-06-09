#!/usr/bin/env zsh

# Metal
#ttab -a iTerm2 -t "METAL_API" -d /Users/lgzarturo/IdeaProjects/metal 'git pull; ./gradlew metal:bootRun'

# Titanium
#ttab -a iTerm2 -t "TITANIUM_API" -d /Users/lgzarturo/IdeaProjects/titanium 'git pull; ./gradlew titanium:bootRun'

# Platinum
#ttab -a iTerm2 -t "PLATINUM_WORKER" -d /Users/lgzarturo/IdeaProjects/titanium 'git pull; sdk use java 11.0.11-zulu; ./gradlew platinum:bootRun'

# Cobalt - Extranet
ttab -a iTerm2 -t "EXTRANET" -d /Users/lgzarturo/Frontend/cobalt 'git pull; yarn; yarn start'

# Adamantium - Motor
ttab -a iTerm2 -t "MOTOR" -d /Users/lgzarturo/Frontend/adamantium 'git pull; yarn; yarn start'

# Agencias
#ttab -a iTerm2 -t "AGENCIAS_API" -d /Users/lgzarturo/IdeaProjects/agencies-admin-api 'git pull; ./gradlew bootRun'

# Zinc
#ttab -a iTerm2 -t "ZINC_API" -d /Users/lgzarturo/IdeaProjects/zinc 'git pull; ./gradlew bootRun'

# Zinc Queue
#ttab -a iTerm2 -t "ZINC_QUEUE" -d /Users/lgzarturo/IdeaProjects/zinc-queue 'git pull; ./gradlew bootRun'
