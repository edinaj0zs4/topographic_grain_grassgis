#!/usr/bin/Rscript
## Get vector with variables for R
	args <- commandArgs(trailingOnly=TRUE)
#
		ELEVATIONTG <- args[1]
		RESOLUTION <- as.numeric(args[2])
		MINNEIGHB <- as.numeric(args[3])
		MAXNEIGHB <- as.numeric(args[4])
		OUT_PDF <- args[5]
		OUT_MAX <- args[6]
		MAP <- as.numeric(args[7])
        grassversion <- as.numeric(args[8])
#
setwd(dirname(OUT_PDF))
errorlog <- file("errorlog.Rout", open="wt")
sink(errorlog, type="message")
#
## Install (if not present) and load required packages
### Check grass version
#
if (Sys.info()["sysname"] != "Windows") {
    installib <- .libPaths()
    if (grep("home", installib)) {
        installib <- grep("home", installib, value=T)
    } else {
        installib <- paste("/home/", Sys.getenv("LOGNAME"), "/R", sep="")
        .libPaths(c(.libPaths(), installib))
    }
} else {
    installib <- .libPaths()[1]
}
#
	if (grassversion == 7) {
			checkinstall <- suppressWarnings(require(rgrass7))
		if (checkinstall=="FALSE") {
				install.packages("GRANbase", dep=TRUE, lib=installib, repos='http://cran.us.r-project.org')
				library(rgrass7)
		} else {library(rgrass7)}
	} else {
			checkinstall <- suppressWarnings(require(spgrass6))
		if (checkinstall=="FALSE") {
				install.packages("spgrass6", dep=TRUE, lib=installib, repos='http://cran.us.r-project.org')
				library(spgrass6, lib.loc=libLocs)
		} else {library(spgrass6)}
	}
#
			checkinstall <- suppressWarnings(require(ggplot2))
	if (checkinstall=="FALSE") {
		install.packages("ggplot2", dep=TRUE, lib=installib, repos='http://cran.us.r-project.org')
		library(ggplot2)
	} else {library(ggplot2)}
#
			checkinstall <- suppressWarnings(require(plyr))
	if (checkinstall=="FALSE") {
		install.packages("plyr", dep=TRUE, lib=installib, repos='http://cran.us.r-project.org')
		library(plyr)
	} else {library(plyr)}

#
## Create the loop calculating relative relief maps &
### steps finding TG value for given cells creating TG map + relative relief map corresponding to TG &
### steps resulting maximum TG for area
#
## Set elevation map as MASK for GRASS
execGRASS("g.rename", raster=c(ELEVATIONTG,"MASK"))
#
# Cells number of neighborhood windows
CELLS <- data.frame("NBNUMBER"=c(3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,51,53,55,57,59,61,63,65,67,69,71,73,75,77,79,81,83,85,87,89,91,93,95,97,99), "CELLNUMBER"=c(5,13,29,49,81,121,169,225,289,361,441,529,625,729,841,961,1089,1225,1369,1521,1681,1849,2025,2209,2401,2601,2809,3025,3249,3481,3721,3969,4225,4489,4761,5041,5329,5625,5929,6241,6561,6889,7225,7569,7921,8281,8649,9025,9409))
#
## Get absolute relief of the study site
execGRASS("r.univar", map="MASK", output="ABSREL.csv", flags="t")
ABSREL <- NULL
ABSREL <- read.csv("ABSREL.csv", header=TRUE, sep="|")
ABSREL <- ABSREL[1,5]
file.remove("ABSREL.csv")
#
#............................................................................................
#
	## Create data frame for TG calculations
	MAXIMUM_TG <- data.frame()
#
	## Calculate relative relief with 3x3 neighborhood to define maximum neighborhood size
		NB <- 3
		RELRELIEF <- paste("temprelief_", formatC(NB, width=3, flag="0"), sep="")
		execGRASS("r.neighbors", input="MASK", output=RELRELIEF, method="range", size=as.integer(NB), flags=c("c", "overwrite"))
		execGRASS("r.univar", map=RELRELIEF, output="RELREL.csv", flags="t")
		STARTREL <- read.csv("RELREL.csv", header=TRUE, sep="|")
		STARTREL <- STARTREL[1,4]
		file.remove("RELREL.csv")
		END_CHECK <- round((ABSREL/STARTREL), digits=0)+1
		END_CHECK <- CELLS[END_CHECK,1]
	if (END_CHECK > MAXNEIGHB) {
		stop("Maximum neighborhood distance was too small, Topographic Grain can't be defined. Please select larger MAXNB or lower resolution of the data.")
	} else {
		if (END_CHECK < 4) {
			stop("Resolution is too coarse, Topographic Grain can't be defined. Please consider higher resolution data.")
		} else {
#
	## Using GRASS GIS functionality within R for loop
		NB <- MINNEIGHB
		MAXNEIGHB <- END_CHECK
if (MAP == 1) {
        while (NB <= MAXNEIGHB)
		{
			RELRELIEF <- paste("temprelief_", formatC(NB, width=3, flag="0"), sep="")
			execGRASS("r.neighbors", input="MASK", output=RELRELIEF, method="range", size=as.integer(NB), flags=c("c", "overwrite"))
			execGRASS("r.univar", map=RELRELIEF, output="RELREL.csv", flags="t")
#
		## Populate dataframe
		DIAMETER <- NB*RESOLUTION
		CELLNUM <- CELLS[which(CELLS$NBNUMBER == NB), ]
		CELLNUM <- CELLNUM[,2]
		AREA <- (RESOLUTION * RESOLUTION * CELLNUM)/1000000 #Total area of cells, not approximated by circle
		TG_NB <- read.csv("RELREL.csv", header=TRUE, sep="|")
		MAX <- TG_NB[1,4]
		file.remove("RELREL.csv")
#
		TG_MAX <- data.frame("NB"=NB, "DIAMETER"=DIAMETER, "AREA"=AREA, "MAX"=MAX)
		MAXIMUM_TG <- rbind(MAXIMUM_TG, TG_MAX)
		NB <- NB + 2
		}
} else {
		while (NB <= MAXNEIGHB)
		{
			RELRELIEF <- paste("temprelief_", formatC(NB, width=3, flag="0"), sep="")
			execGRASS("r.neighbors", input="MASK", output=RELRELIEF, method="range", size=as.integer(NB), flags=c("c", "overwrite"))
			execGRASS("r.univar", map=RELRELIEF, output="RELREL.csv", flags="t")
#
		## Populate dataframe
		DIAMETER <- NB*RESOLUTION
		CELLNUM <- CELLS[which(CELLS$NBNUMBER == NB), ]
		CELLNUM <- CELLNUM[,2]
		AREA <- (RESOLUTION * RESOLUTION * CELLNUM)/1000000 #Total area of cells, not approximated by circle
		TG_NB <- read.csv("RELREL.csv", header=TRUE, sep="|")
		MAX <- TG_NB[1,4]
		file.remove("RELREL.csv")
#
		TG_MAX <- data.frame("NB"=NB, "DIAMETER"=DIAMETER, "AREA"=AREA, "MAX"=MAX)
		MAXIMUM_TG <- rbind(MAXIMUM_TG, TG_MAX)
		NB <- NB + 2
		execGRASS("g.remove", type="raster", pattern="temp*", flags="f") #The relative relief map is no longer necessary, so it will be removed
		}
     }
#
		## Analyse MAX TG values
		## Print results to PDF file
		pdf(file=OUT_PDF, paper="a4r", pointsize=11)
        ## Remove lines where increase is in RR within 0.25 meter
        TOPREACH <- duplicated(round(MAXIMUM_TG[,"MAX"], digits=2))
        MAXIMUM_TG <- MAXIMUM_TG[! TOPREACH,]
#
		rows <- nrow(MAXIMUM_TG)
		EQUATION <- lm(MAXIMUM_TG[,"MAX"] ~ MAXIMUM_TG[,"AREA"])
		COEFFS <- coefficients(EQUATION)
		EXPECTED_VAL <- MAXIMUM_TG$AREA*COEFFS[2] + COEFFS[1]
		DIFF_FROM_EXP <- EXPECTED_VAL - MAXIMUM_TG$MAX
				breakpoint <- which.min(DIFF_FROM_EXP)
				breakpoint <- c(breakpoint-1,breakpoint, breakpoint+1)
				breakpoint <- subset(breakpoint, breakpoint > 1 & breakpoint < rows)
				breakpoint_row <- length(breakpoint)
				leastsquaresvalue <- data.frame()
				for (k in 1:breakpoint_row) {
					breakvalue <- breakpoint[k]
					MAXIMUM_TG_part1 <- MAXIMUM_TG[1:breakvalue,]
					MAXIMUM_TG_part2 <- MAXIMUM_TG[breakvalue:rows,]
					fit1 <- lm(MAXIMUM_TG_part1[,"MAX"] ~ MAXIMUM_TG_part1[,"AREA"])
					fit2 <- lm(MAXIMUM_TG_part2[,"MAX"] ~ MAXIMUM_TG_part2[,"AREA"])
					residsquaresum <- (sum(summary(fit1)$residuals^2) + sum(summary(fit2)$residuals^2))
					break_residsquaresum <- c(breakvalue, residsquaresum)
					leastsquaresvalue <- rbind(leastsquaresvalue, break_residsquaresum)
							}
		knickpoint <- leastsquaresvalue[(which.min(leastsquaresvalue[,2])), 1]
		DEFINED_TG <- MAXIMUM_TG[knickpoint,]
#
		## Show calculation on plot
		TG_PLOT1 <- ggplot(MAXIMUM_TG, aes(x=MAXIMUM_TG[,"AREA"], y=MAXIMUM_TG[,"MAX"])) + xlab("Area (km2)") + ylab("Rel. relief (m)") + theme(panel.background = element_rect(fill="seashell1", color="black"), panel.grid.major = element_line(color="seashell3"), panel.grid.minor = element_line(color="seashell2")) + geom_line(color="seagreen", size=1.15) + geom_point(shape=19, color="darkseagreen2", size=4) + ggtitle(paste("Topographic grain calculated for: ", ELEVATIONTG, " TG:", DEFINED_TG, sep=""))
            MAXIMUM_TG_part1 <- MAXIMUM_TG[1:knickpoint,]
            MAXIMUM_TG_part2 <- MAXIMUM_TG[knickpoint:rows,]
            fit1 <- lm(MAXIMUM_TG_part1[,"MAX"] ~ MAXIMUM_TG_part1[,"AREA"])
            COEFFS1 <- coefficients(fit1)
            fit2 <- lm(MAXIMUM_TG_part2[,"MAX"] ~ MAXIMUM_TG_part2[,"AREA"])
            COEFFS2 <- coefficients(fit2)
		TG_PLOT2 <- TG_PLOT1 + geom_abline(intercept=COEFFS1[1], slope=COEFFS1[2], linetype=2)
		TG_PLOT3 <- TG_PLOT2 + geom_abline(intercept=COEFFS2[1], slope=COEFFS2[2], linetype=2)
		print(TG_PLOT3)
		dev.off()
#
		## Write out table with MAXIMUM_TG calculation
		MAXIMUM_TG <- rbind(MAXIMUM_TG, DEFINED_TG)
		write.csv(MAXIMUM_TG, file=OUT_MAX)
			}
		}

#............................................................................................
## MAP variable defines if only max TG value will be calculated (0) *true-false shell was other way around
## or the map of TG values for every cell will be created as well (1)
if (MAP == 1) {
#
	## Analyse values of TG MAP
		## Calculate rate of RELREL before and after TG and calculate the value from RELREL map for all cells
		RATE <- (MAXIMUM_TG[(rows-1),"MAX"] - MAXIMUM_TG[knickpoint,"MAX"])/(MAXIMUM_TG[knickpoint,"MAX"] - MAXIMUM_TG[1,"MAX"])
		NAME_NEW_REL <- paste("tempRATEVAL_", formatC(MAXIMUM_TG[(rows-1),"NB"], width=3, flag="0"), sep="")
		NAME_ENDMAP <- paste("temprelief_", formatC(MAXIMUM_TG[(rows-1),"NB"], width=3, flag="0"), sep="")
		expression_NEW_REL <- paste(NAME_NEW_REL, "=", NAME_ENDMAP, "*", RATE, sep="")
		execGRASS("r.mapcalc", expression=expression_NEW_REL)
			## Define NB value for every cell where RELREL value is higher than newly calculated value
				for(r in 2:rows) {
				NAME_BREAKMAP <- paste("tempbreakmap_", formatC(NB, width=3, flag="0"), sep="")
				NB <- MAXIMUM_TG[r,"NB"]
				NAME_RELRELMAP <- paste("temprelief_", formatC(NB, width=3, flag="0"), sep="")
				expression_BREAK <- paste(NAME_BREAKMAP, "=", "if(", NAME_NEW_REL, "<=", NAME_RELRELMAP, ",", NB, ", null())", sep="")
				execGRASS("r.mapcalc", expression=expression_BREAK)
								}	
				execGRASS("g.list", type="rast", pattern="tempbreakmap*", separator="pipe", output="MAPLIST.txt")
				allmap <- read.csv("MAPLIST.txt", header=FALSE, sep="|", stringsAsFactors=FALSE)
				allmap <- as.character(allmap)
				file.remove("MAPLIST.txt")
				BREAK_MAPS <- paste(allmap, sep="", collapse=",")
				execGRASS("r.patch", input=BREAK_MAPS, output=paste(ELEVATIONTG, "_NB", sep=""))
				execGRASS("r.null", map=paste(ELEVATIONTG, "_NB", sep=""), null=MAXIMUM_TG[rows,"NB"])
			## Calculate DIAM map to show what diameter that TG value means
				expression_DIAM <- paste(paste(ELEVATIONTG, "_DIAM", sep=""), "=", RESOLUTION, "*", paste(ELEVATIONTG, "_NB", sep=""), sep="")
				execGRASS("r.mapcalc", expression=expression_DIAM)
			## Calculate VAL map to show what relative relief value the given cell has
				relrelmaps <- NULL
				close_bracket <- rep(c(")"), rows)
				for(u in 1:rows) {
				relrelmaps[u] <- paste("if(", paste(ELEVATIONTG, "_NB", sep=""), "=", MAXIMUM_TG[u,"NB"], ",", paste("temprelief_", formatC(MAXIMUM_TG[u,"NB"], width=3, flag="0"), sep=""), ",", sep="")
						}
				relrelmaps <- c(relrelmaps, c("null()"), close_bracket)
				relrelmaps <- paste(relrelmaps, sep="", collapse="")
				expression_VAL <- paste(paste(ELEVATIONTG, "_VAL", sep=""), "=", relrelmaps, sep="")
				execGRASS("r.mapcalc", expression=expression_VAL)
#
	## Keep the temprelief map created by the TG value as resulting relative relief map
		NAME_TGRELREL <- paste("temprelief_", formatC(MAXIMUM_TG[rows+1,"NB"], width=3, flag="0"), sep="")
		NAME_RELRELMAP <- paste(ELEVATIONTG, "_RELREL", sep="")
		execGRASS("g.rename", raster=paste(NAME_TGRELREL, ",", NAME_RELRELMAP, sep=""))
#
	execGRASS("g.remove", type="raster", pattern="temp*", flags=c("f", "quiet"))
            }
execGRASS("g.rename", raster=c("MASK", ELEVATIONTG))
sink()
