"""
n = define(n,numStates=2,numControls=1,X0=[0.,1],XF=[0.,-1.],XL=[0.,-Inf],XU=[1/9,Inf],CL=[-Inf],CU=[Inf])
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 1/1/2017, Last Modified: 1/23/2017 \n
Citations: \n
----------\n
Initially Influenced by: S. Hughes.  steven.p.hughes@nasa.gov
Source: DecisionVector.m [located here](https://sourceforge.net/p/gmat/git/ci/264a12acad195e6a2467cfdc68abdcee801f73fc/tree/prototype/OptimalControl/LowThrust/@DecisionVector/)
-------------------------------------------------------------------------------------\n
"""
function define(n::NLOpt;
                stateEquations::Function=[],
                numStates::Int64=0,
                numControls::Int64=0,
                X0::Array{Float64,1}=zeros(Float64,numStates,1),
                XF::Array{Float64,1}=zeros(Float64,numStates,1),
                XL::Array{Float64,1}=zeros(Float64,numStates,1),
                XU::Array{Float64,1}=zeros(Float64,numStates,1),
                CL::Array{Float64,1}=zeros(Float64,numControls,1),
                CU::Array{Float64,1}=zeros(Float64,numControls,1)
                )

  # validate input
  if  numStates <= 0
      error("\n numStates must be > 0","\n",
              "default value = 0","\n",
            );
  end
  if  numControls <= 0
      error("eventually numControls must be > 0","\n",
            "default value = 0","\n",
            );
  end
  if length(X0) != numStates
    error(string("\n Length of X0 must match number of states \n"));
  end
  if length(XF) != numStates
    error(string("\n Length of XF must match number of states \n"));
  end
  if length(XL) != numStates
    error(string("\n Length of XL must match number of states \n"));
  end
  if length(XU) != numStates
    error(string("\n Length of XU must match number of states \n"));
  end
  if length(CL) != numControls
    error(string("\n Length of CL must match number of controls \n"));
  end
  if length(CU) != numControls
    error(string("\n Length of CU must match number of controls \n"));
  end

  n.stateEquations = stateEquations;
  n.numStates = numStates;
  n.numControls = numControls;
  n.X0 = X0;
  n.XF = XF;
  n.XL = XL;
  n.XU = XU;
  n.CL = CL;
  n.CU = CU;
  return n
end

"""
n = configure(n::NLOpt,Ni=4,Nck=[3, 3, 7, 2];(:integrationMethod => :ps),(:integrationScheme => :lgrExplicit),(:finalTimeDV => false),(:tf => 1))
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 1/1/2017, Last Modified: 1/23/2017 \n
Citations: \n
----------\n
Initially Influenced by: S. Hughes.  steven.p.hughes@nasa.gov
Source: DecisionVector.m [located here](https://sourceforge.net/p/gmat/git/ci/264a12acad195e6a2467cfdc68abdcee801f73fc/tree/prototype/OptimalControl/LowThrust/@DecisionVector/)
-------------------------------------------------------------------------------------\n
"""
function configure(n::NLOpt, args...; kwargs... )
  kw = Dict(kwargs);

  # intial time
  if !haskey(kw,:t0); kw_ = Dict(:t0 => 0); n.t0 = get(kw_,:t0,0);
  else; n.t0 = get(kw,:t0,0);
  end

  # final time
  if !haskey(kw,:finalTimeDV); kw_ = Dict(:finalTimeDV => false); n.finalTimeDV = get(kw_,:finalTimeDV,0);
  else; n.finalTimeDV  = get(kw,:finalTimeDV,0);
  end

  if !haskey(kw,:tf) && !n.finalTimeDV
    error("\n If the final is not a design variable pass it as: (:tf=>Float64(some #)) \n
        If the final time is a design variable, indicate that as: (:finalTimeDV=>true)\n")
  elseif haskey(kw,:tf) && !n.finalTimeDV
    n.tf = get(kw,:tf,0);
  elseif n.finalTimeDV
    n.tf = Any;
  end

  # integration method
  if !haskey(kw,:integrationMethod); kw_ = Dict(:integrationMethod => :ps); n.integrationMethod = get(kw_,:integrationMethod,0);
  else; n.integrationMethod  = get(kw,:integrationMethod,0);
  end

  if n.integrationMethod==:ps
    if haskey(kw,:N)
      error(" \n N is not an appropriate kwargs for :tm methods \n")
    end
    if !haskey(kw,:Ni); kw_ = Dict(:Ni => 1); n.Ni=get(kw_,:Ni,0);        # default
    else; n.Ni = get(kw,:Ni,0);
    end
    if !haskey(kw,:Nck); kw_ = Dict(:Nck => [10]); n.Nck=get(kw_,:Nck,0); # default
    else; n.Nck = get(kw,:Nck,0);
    end
    if !haskey(kw,:integrationScheme); kw_ = Dict(:integrationScheme => :lgrExplicit); n.integrationScheme=get(kw_,:integrationScheme,0); # default
    else;  n.integrationScheme=get(kw,:integrationScheme,0);
    end
    if length(n.Nck) != n.Ni
        error("\n length(Nck) != Ni \n");
    end
    for int in 1:n.Ni
        if (n.Nck[int]<0)
            error("\n Nck must be > 0");
        end
    end
    if  n.Ni <= 0
      error("\n Ni must be > 0 \n");
    end
     n.numPoints = [n.Nck[int] for int in 1:n.Ni];  # number of design variables per interval

    # initialize node data
    if n.integrationScheme==:lgrExplicit
      taus_and_weights = [gaussradau(n.Nck[int]) for int in 1:n.Ni];
    end
    n.τ = [taus_and_weights[int][1] for int in 1:n.Ni];
    n.ω = [taus_and_weights[int][2] for int in 1:n.Ni];
    n = createIntervals(n);
    n = DMatrix(n);

  elseif n.integrationMethod==:tm
    if haskey(kw,:Nck) || haskey(kw,:Ni)
      error(" \n Nck and Ni are not appropriate kwargs for :tm methods \n")
    end
    if !haskey(kw,:N); kw_ = Dict(:N => 10); n.N=get(kw_,:N,0); # default
    else; n.N = get(kw,:N,0);
    end
    if !haskey(kw,:integrationScheme); kw_ = Dict(:integrationScheme => :bkwEuler);  n.integrationScheme=get(kw_,:integrationScheme,0); # default
    else;  n.integrationScheme=get(kw,:integrationScheme,0);
    end
  end

  return n
end
