
# Draw functions ----------------------------------------------------------


# Stage secondary infections when new cases are generated
#
# When a new case is generated, all the secondary infections are also generated and
# loaded into the \code{state_df} row for the primary case. The infections are only
# actually loaded into the simulation at the correct time, through the function
# \code{generate_secondary_infections()} in generate_new_infections.R. To generate
# secondary infections, first the number of potential secondary infections is drawn.
# Then, generation intervals are generated for each potential secondary infection. Finally,
# potential infections are rejected by user-defined criteria, such as being after the
# isolation time for the primary case. Currently, only one type of secondary infection
# algorithm is implemented (the one from Hellewell et al.). The generation intervals are
# generated by a call to \code{draw_generation_interval}.

draw_sec_infects_df <- function(state_df,  sim_params, sim_status, import=FALSE){
  n_cases = nrow(state_df)
    # Following binomial distribution to determine
    # number of sec. infections of each infector 
    # and "generation interval"? of each sec. infection
  col_names <- c('n_infect', 'incubation_int', 'serial_int')
  n_cols <- length(col_names)
  infect_rate <- exp(-0.5*8256/(8256-length(sim_status$alrdy_infected)))*sim_params$p_infect
  update_contact_ind_index <- contact_ind_index[-sim_status$alrdy_infected]#contact_ind_index[-state_df$case_id] # here, need to remove all infected case ids
  
  # infect_rate <- exp(-0.6*8256/(8256-length(sim_status$alrdy_infected)))*sim_params$p_infect
  
  # n_infect_reg <- rbinom(n_cases, size = state_df$contact_number_regular, prob = infect_rate)
  # n_infect_trans <- rbinom(n_cases, size = state_df$contact_number_transient, prob = infect_rate*0.009)
  # n_regular <- as.data.frame(sim_params$regular_contact_matrix)[state_df$case_id,update_contact_ind_index]
  n_regular <- sim_params$regular_contact_matrix[state_df$case_id,update_contact_ind_index]
  
  if(nrow(n_regular)>=1)
  # if(!is.null(n_regular))
  {
    n_infect_reg<- unlist(lapply(1:nrow(n_regular),
                                 function(i)
                                 {sum(n_regular[i,])*infect_rate}))
  }

  # for each infector, the number of infection should be n_reg_contact*infect_rate
  
  # n_infect_reg <- rbinom(n_cases, size = state_df$contact_number_regular, prob = infect_rate)
  # n_infect_trans <- rbinom(n_cases, size = state_df$contact_number_transient, prob = infect_rate*0.009)
  # n_transient <- as.data.frame(sim_params$transit_contact_matrix)[state_df$case_id,update_contact_ind_index]
  n_transient <- sim_params$transit_contact_matrix[state_df$case_id,update_contact_ind_index]
  
  if(nrow(n_transient) >=1)
  # if(!is.null(n_transient))
  {
    n_infect_trans <- unlist(lapply(1:nrow(n_transient),
                                    function(i)
                                    {sum(n_transient[i,])*infect_rate*0.009}))
  }

  # if(length(sim_status$alrdy_infected)>1000)
  # n_infect_reg <- rnbinom(n_cases, mu = state_df$contact_number_regular*infect_rate, size = 0.7)
  # n_infect_trans <- rnbinom(n_cases, mu = state_df$contact_number_transient*infect_rate*0.01, size = 0.7)
  # number of secondary cases from infector i, here number of i =n_cases
  # to assign the infectees
  set.seed(1111)
  new_case_id_reg <- lapply(1:length(state_df$case_id),
                            function(i) 
                            {
                              if(n_infect_reg[i]==0){
                                contact_temp_ind <- NULL
                              }else{
                                contact_temp_ind <- sample(update_contact_ind_index,#contact_ind_index[-case_id],
                                                           n_infect_reg[i],replace=FALSE, prob = sim_params$trans_tree_reg[state_df$case_id[i],update_contact_ind_index])
                              }

                              contact_temp_ind
                            }
  )
  if(length(new_case_id_reg)>0){
    for(i in 1:length(new_case_id_reg)){
      # print(i)
      if(i >=2){
        rm <- which(new_case_id_reg[[i]] %in% new_case_id_reg[[(i-1)]])
        if(length(rm)>0){
          new_case_id_reg[[i]] <- new_case_id_reg[[i]][-rm]
        }
      }
    }
    new_case_id_reg <- new_case_id_reg
  }
  n_infect_reg <- unlist(lapply(new_case_id_reg,length))
  new_case_id_trans <- lapply(1:length(state_df$case_id),
                              function(i) 
                              {if(n_infect_reg[i]==0){
                                contact_temp_ind <- NULL
                              }else{
                                contact_temp_ind <- sample(update_contact_ind_index,#contact_ind_index[-case_id],
                                                           n_infect_trans[i],replace=FALSE, prob = sim_params$trans_tree_trans[state_df$case_id[i],update_contact_ind_index])
                              }
                                contact_temp_ind
                              }
  )
  if(length(new_case_id_trans)>0){
    for(i in 1:length(new_case_id_trans)){
      # print(i)
      if(i >=2){
        rm <- which(new_case_id_trans[[i]] %in% new_case_id_trans[[(i-1)]])
        if(length(rm)>0){
          new_case_id_trans[[i]] <- new_case_id_trans[[i]][-rm]
        }
      }
    }
    new_case_id_trans <- new_case_id_trans
  }
  n_infect_trans <- unlist(lapply(new_case_id_trans,length))
  n_infect <- n_infect_reg + n_infect_trans
  
  
  new_case_id <- lapply(1:length(state_df$case_id), function(i) c(new_case_id_reg[[i]],new_case_id_trans[[i]]))
 
  set.seed(sim_params$seed_id)
  # Determine incubation period and serial interval of each secondary infections from each infector source case
  incubation_period <- mapply(draw_incubation_interval, # FUN to be called on each X
                           n_infect, # X to loop over, n_infect is the secondary cases
                           MoreArgs=list(sim_params=sim_params), # additional required input for FUN
                           SIMPLIFY = FALSE) # force return as list
    
    # lapply(seq_along(incubation_length),function(i) unlist(incubation_length[i])+unlist(serial_int[i])) # not run on Nov 24, since both of them are list

  first_day_contagious <- rep(0,n_cases)
    # Infect-er
    # Switches for each contagious scenario
  is_T_and_S <- state_df$is_traced * state_df$is_symptomatic # traced and symptomatic
  is_T_and_nS <- state_df$is_traced * (1-state_df$is_symptomatic) # traced and not sympt
  is_nT_and_S <- (1-state_df$is_traced) * state_df$is_symptomatic # not traced and sympt
  is_nT_and_nS <- (1-state_df$is_traced) * (1-state_df$is_symptomatic) # not traced and not sympt
    # Length of contagious period for each scenario
  T_and_S_time <- state_df$incubation_length + state_df$isolation_delay # Contagious period. Delay for primary not yet isolated folded into isolation delay: which is contagiouslength
  T_and_nS_time <- state_df$infection_length # no isolation if no symptoms, infection_length is the constant = 14.
  nT_and_S_time <- state_df$incubation_length + state_df$isolation_delay # isolated some time after symptoms
  nT_and_nS_time <- state_df$infection_length  # no isolation if no symptoms
  last_day_contagious <- is_T_and_S * T_and_S_time   +
                         is_T_and_nS * T_and_nS_time  +
                         is_nT_and_S * nT_and_S_time  +
                         is_nT_and_nS * nT_and_nS_time
    # Ensure no "last day contagious" is larger than infection_length days (would be removed as inactive)
  longer_than_contag_len <- last_day_contagious > state_df$infection_length
  last_day_contagious[longer_than_contag_len] <- state_df$infection_length[longer_than_contag_len]
    # Also, to avoid weird negative values in case somehow the isolated infector still caused
    # this case to happen, make all negative values be zero (would not allow any sec infects)
  neg_last_day <- last_day_contagious < 0
  last_day_contagious[neg_last_day] <- 0
  
  # if the first day of contagious is later than generation interval (from infector), then it would be kept in the infectee list. 
  # genertion interval is generated from gamma distribution.
  generation_int <- mapply(draw_generation_interval, # FUN to be called on each X
                           n_infect, # X to loop over
                           MoreArgs=list(sim_params=sim_params), # additional required input for FUN
                           SIMPLIFY = FALSE) # force return as list
  generation_int <- lapply(generation_int,sort)
  # first_day_contagious <- lapply(seq_along(generation_int),function(i) rep(first_day_contagious[i],length(generation_int[[i]])))
  # last_day_contagious <- lapply(seq_along(generation_int),function(i) rep(last_day_contagious[i],length(generation_int[[i]])))
    # Split the generation interval list.
    # Keep the valid infections for model, store the rest for record keeping
  generation_keep <- lapply(
    seq_along(generation_int),
    function(ii, generation, first_day, last_day){
      index_to_keep <- (generation[[ii]]  > first_day[ii]) &
        (generation[[ii]]< last_day[ii])
      return(generation[[ii]][index_to_keep])
    },
    generation = generation_int,
    first_day = first_day_contagious,
    last_day = last_day_contagious
    )
  
  generation_reject <- lapply(
    seq_along(generation_int),
    function(ii, generation, first_day, last_day){
      index_to_keep <- (generation[[ii]] > first_day[ii]) &
        (generation[[ii]]  < last_day[ii])
      return(generation[[ii]][!index_to_keep])
      },
      generation=generation_int,
      first_day=first_day_contagious,
      last_day=last_day_contagious
    )
  
  

  infectee_keep <- lapply(
    seq_along(new_case_id),
    function(ii, infectee, generation, first_day, last_day){
      index_to_keep <- (generation[[ii]]  > first_day[ii]) &
        (generation[[ii]]< last_day[ii]) 
      return(infectee[[ii]][index_to_keep])
    },
    infectee = new_case_id,
    generation = generation_int,
    first_day = first_day_contagious,
    last_day = last_day_contagious
  )
  infectee_reject <- lapply(
    seq_along(generation_int),
    function(ii, infectee,generation, first_day, last_day){
      index_to_keep <- (generation[[ii]] > first_day[ii]) &
        (generation[[ii]]  < last_day[ii])
      return(infectee[[ii]][!index_to_keep])
    },
    infectee = new_case_id,
    generation=generation_int,
    first_day=first_day_contagious,
    last_day=last_day_contagious
  )
  # state_df$infectee_id <- infectee_keep
  
    # Get number of actual infections
  n_infect <- sapply(generation_keep,length)
    # Will probably move this outside of the if-block when other methods added
  return(list(n_reg=n_infect_reg,n_trans=n_infect_trans,n=n_infect,generation=generation_keep,
              infectee=infectee_keep,non_infects=generation_reject,non_infectee=infectee_reject))
  
}

## Epidemiology parameters 
draw_generation_interval <- function(n, sim_params) # used in the draw_sec_inf
{
  generation_ints <- rgamma(n, shape=sim_params$generation_int_params$shape, 
                            rate=sim_params$generation_int_params$rate)
  return(generation_ints)
}

draw_incubation_interval <- function(n, sim_params) # used in the draw_sec_inf
{
  #generation_int_dist=='gamma'
  # incubation_ints <- rnorm(n, mean=sim_params$incub_params$mean, sd = sim_params$incub_param$sd) # mean = 3, sd=1
  # and within 2 to 5 days
  # incubation_ints[incubation_ints<=2] <- 2
  # incubation_ints[incubation_ints>=7] <- 7
  incubation_ints <- rgamma(n, shape=sim_params$incub_params$shape, scale  = sim_params$incub_param$scale)
  return(incubation_ints)
}

draw_symptomatic_status <- function(n, sim_params){
  return(runif(n) < sim_params$p_sym)
} # used in the create_df

## From network about the contact information
#  need to take care of the case_id!!
find_contact_number <- function(case_id, contact_ind_index, contact_matrix, sim_status) # actualy, not very accurate to call 'rate', by network method, it should named as 'number'.
{
  # if(any(case_id%in%contact_ind_index))
  # {
  #   do.call('c',lapply(case_id[which(case_id%in%contact_ind_index)],function(i) sum(contact_matrix[i,])))
  # }else{
  #   rep(0,length(case_id))
  # }
  # do.call('c',lapply(case_id,function(i) sum(contact_matrix[i,contact_ind_index[-(sim_status$alrdy_infected)]])))
  do.call('c',lapply(case_id,function(i) sum(contact_matrix[i,-(sim_status$alrdy_infected)])))
  
}

## Draw others related to policies
# Draw delay to isolation periods for new cases
#
# The number of days between symptom onset and isolation, which may be negative if isolation
# occurs prior to symptom onset (as sometimes the case with traced cases).
#
# Aim to use this number of days to calculate the contagious length.
#
# Within the list object \code{sim_params$iso_delay_params}, the user can define several delay
# periods based on tracing type, tracing status.

# Traced cases have their delays measured from the index case's isolation time, so traced cases
# may isolate prior to their own symptom onset. 
# Untraced cases have delays measured from the start of their own symptom onset. 
# The untraced timeline is always considered for traced cases, so that
# if a traced case would have been isolated earlier just because of their symptom onset timeline,
# they would isolate at this earlier time.
# return: A vector of length n for case delay to isolation, measured from start of symptom onset (double)

draw_isolation_delay_period <- function(state_df, sim_params,
                                        primary_state_df=NULL,
                                        primary_case_ids=NULL){
  iso_delay_params <- sim_params$iso_delay_params
  # iso_delay_params$dist=='weibull'
  n <- nrow(state_df)
  # Draw from Weibull distribution initially
  iso_delay<-rweibull(
      n,
      shape=iso_delay_params$shape, # the isolation rate
      scale=iso_delay_params$scale # mean/around mean of isolation lengths
    )
    # Modify actual delay time based on tracing and status of primary case
    # Only when primary_state_df provided (i.e. a secondary case)
    if (!is.null(primary_state_df)){
      # Get rows of primary_state_df matching primary cases
      infector_df <- subset(primary_state_df,case_id %in% primary_case_ids)
      # Calculate how many days between now and infector being isolated
      infector_df$d_until_iso <- infector_df$incubation_length +
        infector_df$isolation_delay -
        infector_df$days_infected
      # For each new case, determine the actual isolation delay
      iso_delay2 <- vapply(X=seq_along(iso_delay), FUN=function(ii){
        if (state_df[ii,]$is_traced){ # If traced, then check infector isolation time
          d_until_onset <- state_df$incubation_length[ii]
          d_until_pri_iso <- subset(infector_df,case_id==primary_case_ids[ii])$d_until_iso
          # If secondary case onset is *after* primary's isolation time, delay set to 0
          if (d_until_onset > d_until_pri_iso){
            return(0) # NB: return is to vapply
          } else{ # otherwise, delay is until primary case is isolated
            return(d_until_pri_iso-d_until_onset) # NB: return is to vapply
          }
        } else{ # If not traced, then use drawn iso_delay value
          return(iso_delay[ii]) # NB: return is to vapply
        }
      }, FUN.VALUE=999)
      # Update iso_delay vector to account for tracing
      iso_delay <- iso_delay2
    }
  
  return(iso_delay)
}
###Traced issue (infect-er) 
# to get the 0-1 vector to show whether the infect-er is traced by BP device
draw_traced_status <- function(n, sim_params){
  if (sim_params$vary_trace){
    if(n<10){
      p_trace<-sim_params$p_trace_vary[1] # there is unaware to trace, p_trace_vary = 0.1
    }
    else if(n<20){
      p_trace<-sim_params$p_trace_vary[2] # some could not be traced, p_trace_vary =0.5
    } else{
      p_trace<-sim_params$p_trace_vary[3] # some could not be traced, p_trace_vary = 0.7 # 30% of the BP broken
    }
    return(runif(n) < p_trace)
  } else{ # otherwise, use fixed tracing value
    return(runif(n) < sim_params$p_trace)
  }
}




# generate new infections ------------------------------------------------
# generate the potential secondary cases of infectees
generate_secondary_infections <- function(state_df, sim_params){
  sec_infection_sources <- c()
  infectee_case_id <- c()
  if (nrow(state_df)>0){
    # TODO: Can we replace this for-loop?
    for (row in 1:nrow(state_df)){
      generation_int <- state_df$generation_intervals[[row]]
      infectee_id <- state_df$infectee_id[[row]]
      # Find which entries in generation_int are causing new secondary infections from this case
      sec_inf_ind <- state_df$days_infected[row] > generation_int
      n_sec_inf <- sum(sec_inf_ind)
     
      if (n_sec_inf < 1){
        next # no new infections caused by this case this step
      }
      
      # Add case_id to output list once for each new secondary infection case
      source_case_id <- state_df$case_id[row]
      sec_infection_sources <- c(sec_infection_sources,rep(source_case_id,n_sec_inf))
      infectee_case_id <- c(infectee_case_id,infectee_id[sec_inf_ind])
      # Decrease infection counter and remove from generation interval list
      state_df$n_sec_infects[row] <- state_df$n_sec_infects[row] - n_sec_inf
      state_df$generation_intervals[[row]] <- generation_int[!sec_inf_ind]
      state_df$infectee_id[[row]] <- infectee_id[!sec_inf_ind]
      
    }
    if(length(which(duplicated(state_df$case_id)))>0){
      rm <- which(duplicated(state_df$case_id))
      state_df <- state_df[-rm,]
      sec_infection_sources <- sec_infection_sources[-rm]
      infectee_case_id <- infectee_case_id[-rm]
    }
    # if infectees were genereted by the different case_id on the same day, we only keep one
    # if(any(duplicated(infectee_case_id)))
    # {
    #   
    # }
    return(list(updated_state_df=state_df, sec_infection_sources=sec_infection_sources, infectee_case_id = infectee_case_id))
  }
  else{
    return(list(updated_state_df=state_df, sec_infection_sources=NULL, infectee_case_id=NULL))
  }
}

# Create and record the state data ----------------------------------------

### to track active cases in the simulation.
create_state_df <- function(case_id,#n_cases, 
                            sim_params, sim_status,
                            # trans_tree_reg,
                            # trans_tree_trans,
                            initialize=FALSE, 
                            import=FALSE,
                            primary_state_df=NULL, 
                            primary_case_ids=NULL){
  # List of columns in state df
  col_names <- c("case_id", "status", 
                 "is_traced","is_symptomatic", 
                 "days_infected", "incubation_length",
                 "isolation_delay", "infection_length", #'generation_interval',
                 "contact_number_regular","contact_number_transient",
                 "n_sec_infects") # infection_length here means valid period to generate secondary cases.
  n_cols <- length(col_names)
  # case_id <- unique(case_id)
  n_cases <- length(case_id)
  # Create data frame
  state_df <- data.frame(matrix(nrow=n_cases,ncol=n_cols, dimnames=list(NULL,col_names)))
  
  # If no cases being added, then return empty data frame
  # This should only happen when initializing
  if (n_cases==0){
    return(state_df)
  }
  
  # Fill in start values
  if (initialize){
    state_df$case_id <- case_id#1:n_cases # special case for starting out
  } else{
    state_df$case_id <- case_id#sim_status$new_case_id#c(case_id,sim_status$new_case_id)#sim_status$last_case_id + 1:n_cases # n_cases is the secondary cases
  }
  
  state_df$status <- rep("incubation", n_cases)
  if (initialize || import){
    state_df$is_traced <- rep(FALSE, n_cases)
  } else{
    state_df$is_traced <- draw_traced_status(n_cases,sim_params)
  }

  # if (!is.null(primary_state_df)){
  #   state_df$is_traced <- draw_traced_status(n = ,sim_params = sim_params)
  # } else {
  #   state_df$is_traced <- rep(FALSE, n_cases)
  # }
  
  state_df$is_symptomatic <- draw_symptomatic_status(n_cases,sim_params)
  state_df$days_infected <- rep(0, n_cases)
  state_df$incubation_length <- draw_incubation_interval(n_cases,sim_params)
  # state_df$generation_interval <- draw_generation_interval(n_cases,sim_params)
  state_df$infection_length <- 14
  
  state_df$isolation_delay <- draw_isolation_delay_period(state_df,sim_params
                                                          # primary_state_df=primary_state_df,
                                                          # primary_case_ids=primary_case_ids
                                                          )
  
  state_df$contact_number_regular <- find_contact_number(case_id, contact_ind_index=contact_ind_index, 
                                                         contact_matrix = sim_params$regular_contact_matrix,sim_status)
  state_df$contact_number_transient <- find_contact_number(case_id, contact_ind_index=contact_ind_index, 
                                                         contact_matrix = sim_params$transit_contact_matrix,sim_status)
  
  sec_infect_out <- draw_sec_infects_df(state_df, sim_params, sim_status, import=F)
  # Set up the transmission tree, combine with the transmission tree, to define who infect whom
  
  state_df$n_sec_infects<- sec_infect_out$n
  state_df$n_sec_infects_reg<- sec_infect_out$n_reg
  state_df$n_sec_infects_trans<- sec_infect_out$n_trans
  state_df$generation_intervals<- sec_infect_out$generation
  state_df$non_generation <- sec_infect_out$non_infects
  state_df$infectee_id <- sec_infect_out$infectee
  state_df$non_infectee_id <- sec_infect_out$non_infectee

  return(state_df)
}



### to record active cases in the simulation.
create_record_df <- function(state_df, sim_status, initialize=FALSE, infection_source=NULL){
  # List of columns to record
  col_names <- c("case_id", "source", "is_traced", "is_symptomatic", 
                 "d_incub", "d_iso_delay","d_infection", "num_of_contacts", 
                 "n_sec_infects", "d_generation_ints",
                 "t_inf", #"t_symp", "t_iso", "t_inact",
                  "s_status", "non_infect_generations")
  n_cols <- length(col_names)
  # Get number of rows
  n_rows <- nrow(state_df)
  # Create data frame
  rec_df <- data.frame(matrix(nrow=n_rows,ncol=n_cols, dimnames=list(NULL,col_names)))
  
  # If no cases being added, then return empty data frame
  # This should only happen when initializing
  if (n_rows==0){
    return(rec_df)
  }
  
  # Populate data frame
  rec_df$case_id <- state_df$case_id
  if (initialize){
    rec_df$source <- rep("initial", n_rows) # initial cases
  } else{
    rec_df$source <- infection_source # vector of source case_ids or import source provided
  }
  rec_df$is_traced <- state_df$is_traced
  rec_df$is_symptomatic <- state_df$is_symptomatic
  rec_df$d_incub <- state_df$incubation_length
  rec_df$d_iso_delay <- state_df$isolation_delay
  rec_df$d_infection <- state_df$infection_length
  rec_df$num_of_contacts <- state_df$contact_number
  rec_df$n_sec_infects <- state_df$n_sec_infects
  rec_df$d_generation_ints <- state_df$generation_intervals
  rec_df$infectee_case_ids <- state_df$infectee_id
  rec_df$t_inf <- rep(sim_status$t, n_rows)
  rec_df$s_status <- state_df$status
  rec_df$non_infect_generations <- state_df$non_infect_generations
  
  return(rec_df)
}




# Simulation process ------------------------------------------------------

step_simulation <- function(sim_status, state_df, 
                            rec_df,
                            sim_params){
  # Increment time
  sim_status$t <- sim_status$t + sim_params$dt
  # Update timestamp of current infections
  state_df$days_infected <- state_df$days_infected + sim_params$dt
  sim_status$alrdy_infected <- unique(c(sim_status$alrdy_infected,state_df$case_id))
  # Determine which cases will cause infections this step
  gen_sec_infect_out <- generate_secondary_infections(state_df, sim_params)
  state_df <- gen_sec_infect_out$updated_state_df
  sec_infs_source <- gen_sec_infect_out$sec_infection_sources
  infectee_case_id <- gen_sec_infect_out$infectee_case_id
  n_sec_infections <- length(sec_infs_source)

  # If new infections, create a temporary state and rec dataframes for the new cases
  # Also update rec_df for the origin cases and sim_status for case_id info
  if (n_sec_infections > 0){
    # Create new state_df for new cases
    new_case_id <- infectee_case_id#state_df$case_id[nrow(state_df)]
    if(any(new_case_id%in%sim_status$alrdy_infected)){
      rm <- which(new_case_id%in%sim_status$alrdy_infected)
      new_case_id <- new_case_id[-rm]
      sec_infs_source <- sec_infs_source[-rm]
    }
    sim_status$alrdy_infected <- unique(c(sim_status$alrdy_infected,new_case_id))
    sim_status$new_case_id <- new_case_id
    sim_status$sourced_id <- c(sim_status$sourced_id,sec_infs_source)
    sec_cases_state_df <- create_state_df(case_id = new_case_id,#n_sec_infections,
                                          sim_params=sim_params,
                                          sim_status
                                          )
    if(length(which(duplicated(sec_cases_state_df$case_id)))>0)
    {
      rm <- which(duplicated(sec_cases_state_df$case_id))
      sec_cases_state_df <-  sec_cases_state_df[-rm,]
      sec_infs_source <- sec_infs_source[-rm]
    }
    # Update last_case_id
    # sim_status$new_case_id <- sec_cases_state_df$case_id
    # Create new rec_df for new cases
    sec_cases_rec_df <- create_record_df(sec_cases_state_df, sim_status, infection_source=sec_infs_source)
    # TODO: Update rec_df of the origin cases (so no tracking of this yet)
    n_sec_infections <- nrow(sec_cases_state_df)
    
  }

  set.seed(seed_id)
  # First, identify and mark all cases where infection has ended, regardless of status
  cases_to_inact <- state_df$days_infected > state_df$infection_length
  n_cases_to_inact <- sum(cases_to_inact)
  if (n_cases_to_inact > 0){
    # Update state_df
    state_df$status[cases_to_inact] <- "inactive"
    # Update rec_df
    ids_to_inact <- state_df$case_id[cases_to_inact]
    rec_df$s_status[rec_df$case_id %in% ids_to_inact] <- "inactive"
  }
  
  # Identify all remaining cases that are eligible for advancement to next stage
  # Doing it now prevents checking advanced cases for another advancement
  cases_adv_inc <- (state_df$status=="incubation") &
    (
      (state_df$days_infected > state_df$incubation_length) |
        (state_df$days_infected > state_df$incubation_length + state_df$isolation_delay)
    )
  cases_adv_symp <- (state_df$status=="symptomatic") &
    (state_df$days_infected > (state_df$incubation_length + state_df$isolation_delay))
  cases_adv_asymp <- (state_df$status=="asymptomatic") &
    (state_df$days_infected > (state_df$incubation_length + state_df$isolation_delay))
  
  # Advance current infections from incubation to next stage
  # Goes to symptomatic or asymptomatic based on $is_symptomatic
  # Symptomatic cases that are traced goes right to isolation
  n_cases_adv_inc <- sum(cases_adv_inc)
  if (n_cases_adv_inc > 0){
    # Check whether advancing right to isolation (i.e. delay short enough)
    past_iso_delay <- state_df$days_infected > (state_df$incubation_length + state_df$isolation_delay)
    # Update state_df
    to_symp <- cases_adv_inc & state_df$is_symptomatic & !past_iso_delay
    to_iso  <- cases_adv_inc & past_iso_delay
    to_asymp <- cases_adv_inc & !state_df$is_symptomatic & !past_iso_delay
    state_df$status[to_symp] <- "symptomatic"
    state_df$status[to_iso] <- "isolated"
    state_df$status[to_asymp] <- "asymptomatic"
    # Update rec_df
    # New symptomatic cases
    ids_to_symp <- state_df$case_id[to_symp]
    # rec_df$t_symp[rec_df$case_id %in% ids_to_symp] <- sim_status$t
    rec_df$s_status[rec_df$case_id %in% ids_to_symp] <- "symptomatic"
    # New isolated cases
    ids_to_iso <- state_df$case_id[to_iso]
    # rec_df$t_symp[rec_df$case_id %in% ids_to_iso] <- sim_status$t
    # rec_df$t_iso[rec_df$case_id %in% ids_to_iso] <- sim_status$t
    rec_df$s_status[rec_df$case_id %in% ids_to_iso] <- "isolated"
    # New asymptomatic cases
    ids_to_asymp <- state_df$case_id[to_asymp]
    rec_df$s_status[rec_df$case_id %in% ids_to_asymp] <- "asymptomatic"
  }
  
  # Advance current infections from symptomatic to isolated after delay
  n_cases_adv_symp <- sum(cases_adv_symp)
  if (n_cases_adv_symp > 0){
    # Update state_df
    state_df$status[cases_adv_symp] <- "isolated"
    # Update rec_df
    ids_to_iso <- state_df$case_id[cases_adv_symp]
    # rec_df$t_iso[rec_df$case_id %in% ids_to_iso] <- sim_status$t
    rec_df$s_status[rec_df$case_id %in% ids_to_iso] <- "isolated"
  }
  
  # Advance current infections from asymptomatic to isolated after delay
  n_cases_adv_asymp <- sum(cases_adv_asymp)
  if (n_cases_adv_asymp > 0){
    # Update state_df
    state_df$status[cases_adv_asymp] <- "isolated"
    # Update rec_df
    ids_to_iso <- state_df$case_id[cases_adv_asymp]
    # rec_df$t_iso[rec_df$case_id %in% ids_to_iso] <- sim_status$t
    rec_df$s_status[rec_df$case_id %in% ids_to_iso] <- "isolated"
  }
  
  # Remove isolated and inactive cases from state_df
  trunc_state_df<-state_df[(state_df$status != 'isolated') & (state_df$status != 'inactive'),]
  # trunc_state_df<-state_df[(state_df$status == 'isolated') | (state_df$status == 'inactive'),]
  
  # Add secondary infections to state_df and rec_df
  if (n_sec_infections > 0){
    out_state_df <- rbind(trunc_state_df, sec_cases_state_df)
    out_rec_df <- rbind(rec_df, sec_cases_rec_df)
  } else{
    out_state_df <- trunc_state_df
    out_rec_df <- rec_df
  }
  
  # Add imported infections to output state_df and rec_df
  # if (n_imp_infections > 0){
  #   out_state_df <- rbind(out_state_df, imp_cases_state_df)
  #   # out_rec_df <- rbind(out_rec_df, imp_cases_rec_df)
  # }
  # 
  # Return updated inputs
  return(list(status=sim_status, state=out_state_df, 
              record=out_rec_df,
              new_sec_cases=length(sec_infs_source)#,new_imp_cases=n_imp_infections
              ))
}


