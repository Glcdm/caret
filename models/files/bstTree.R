modelInfo <- list(label = "Boosted Tree", 
                  library = c("bst", "plyr"),
                  type = c("Regression", "Classification"),
                  parameters = data.frame(parameter = c('mstop', 'maxdepth', 'nu'),
                                          class = c("numeric", "numeric", "numeric"),
                                          label = c('# Boosting Iterations', 'Max Tree Depth', 'Shrinkage')),
                  grid = function(x, y, len = NULL, search = "grid")  {
                    if(search == "grid") {
                      out <- expand.grid(mstop = floor((1:len) * 50), 
                                         maxdepth = seq(1, len), 
                                         nu = .1)
                    } else {
                      out <- data.frame(mstop = sample(1:500, replace = TRUE, size = len),        
                                        maxdepth = sample(1:10, replace = TRUE, size = len),         
                                        nu = runif(len, min = .001, max = .6))
                    }
                    out
                  },
                  loop = function(grid) {   
                    loop <- ddply(grid, .(maxdepth, nu), function(x) c(mstop = max(x$mstop)))
                    submodels <- vector(mode = "list", length = nrow(loop))
                    for(i in seq(along = loop$mstop))
                    {
                      index <- which( grid$maxdepth == loop$maxdepth[i] & grid$nu == loop$nu[i])
                      subTrees <- grid[index, "mstop"] 
                      submodels[[i]] <- data.frame(mstop = subTrees[subTrees != loop$mstop[i]])
                    }      
                    list(loop = loop, submodels = submodels)
                  },
                  fit = function(x, y, wts, param, lev, last, classProbs, ...) { 
                    
                    theDots <- list(...)
                    modDist <- if(is.factor(y)) "hinge" else "gaussian"
                    
                    y <- if(is.factor(y)) ifelse(y == lev[1], 1, -1) else y
                    
                    if(any(names(theDots) == "ctrl"))
                    {
                      theDots$ctrl$mstop <- param$mstop
                      theDots$ctrl$nu <- param$nu
                    } else {
                      theDots$ctrl <- bst_control(mstop = param$mstop, nu = param$nu)
                    }
                    if(any(names(theDots) == "control.tree"))
                    {
                      theDots$control.tree$maxdepth <- param$maxdepth
                    } else {
                      theDots$control.tree <- list(maxdepth = param$maxdepth)
                    }
                    
                    
                    modArgs <- list(x = x, y = y, family = modDist, learner = "tree")
                    modArgs <- c(modArgs, theDots)
                    
                    do.call("bst", modArgs)
                    },
                  predict = function(modelFit, newdata, submodels = NULL) {
                    if(modelFit$problemType == "Classification")
                    {
                      out <- predict(modelFit, newdata, type = "class", mstop = modelFit$submodels$mstop)
                      out <- ifelse(out == 1, modelFit$obsLevels[1], modelFit$obsLevels[2])
                    } else {
                      out <- predict(modelFit, newdata, type = "response", mstop = modelFit$submodels$mstop)
                    }
                    
                    if(!is.null(submodels))
                    {
                      tmp <- vector(mode = "list", length = nrow(submodels) + 1)
                      tmp[[1]] <- out
                      
                      for(j in seq(along = submodels$mstop))
                      {
                        if(modelFit$problemType == "Classification")
                        {
                          bstPred <- predict(modelFit, newdata, type = "class", mstop = submodels$mstop[j])
                          tmp[[j+1]] <- ifelse(bstPred == 1, modelFit$obsLevels[1], modelFit$obsLevels[2])
                        } else {
                          tmp[[j+1]]  <- predict(modelFit, newdata, type = "response", mstop = submodels$mstop[j])
                        }
                      }
                      out <- tmp
                    }
                    out         
                  },
                  levels = function(x) x$obsLevels,
                  tags = c("Tree-Based Model", "Ensemble Model", "Boosting"),
                  prob = NULL,
                  sort = function(x) x[order(x$mstop, x$maxdepth, x$nu),] )
