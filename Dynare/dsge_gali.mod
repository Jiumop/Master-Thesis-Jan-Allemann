% 
%----------------------------------------------------------------
% Extension switches (set to 1 to activate)
%----------------------------------------------------------------
@#define SWISS_CALIBRATION = 0    // Use Swiss parameters (Cuche-Curti et al. 2009)
@#define HABIT_FORMATION = 0      // Habit persistence in consumption
@#define INTEREST_SMOOTHING = 0   // Gradual interest rate adjustment
@#define INDEXATION = 0          // Price indexation
@#define INCOMPLETE_PASSTHROUGH = 0  // Incomplete exchange rate pass-through
@#define ER_LEANING = 0           // Exchange rate leaning in Taylor rule
@#define REGIME_DEPENDENT = 0     // Regime-dependent parameters

%----------------------------------------------------------------
% Variables
%----------------------------------------------------------------
var y_gap pi_h i r_nat s pi p_h p er d_er a nu
@#if INCOMPLETE_PASSTHROUGH == 1
    pi_m        // Import price inflation
@#endif
;

varexo eps_nu;

%----------------------------------------------------------------
% Parameters
%----------------------------------------------------------------
parameters betta siggma varphi alppha epsilon theta upsilon eta
    rho_nu rho_a phi_pi phi_y
@#if HABIT_FORMATION == 1
    h           // Habit parameter
@#endif
@#if INTEREST_SMOOTHING == 1
    rho_i       // Interest rate smoothing
@#endif
@#if INDEXATION == 1
    gamma       // Price indexation parameter
@#endif
@#if INCOMPLETE_PASSTHROUGH == 1
    alpha_pass  // Pass-through coefficient
    alpha_m     // Import share in CPI
@#endif
@#if ER_LEANING == 1
    phi_ds      // Exchange rate leaning coefficient
@#endif
@#if REGIME_DEPENDENT == 1
    phi_pi_A phi_pi_B     // Inflation response (Regime A/B)
    phi_ds_A phi_ds_B     // ER leaning (Regime A/B)
@#endif
;

%----------------------------------------------------------------
% Parametrization
%----------------------------------------------------------------
@#if SWISS_CALIBRATION == 1
    // ========================================
    // SWISS CALIBRATION (Cuche-Curti et al. 2009)
    // ========================================
    betta   = 0.995;    // Quarterly discount factor (standard NK)
    siggma  = 1.32;     // Inverse intertemporal elasticity
    varphi  = 1.00;     // Inverse Frisch elasticity
    alppha  = 1/4;      // Capital share
    epsilon = 9;        // Demand elasticity
    theta   = 0.75;     // Calvo parameter (4-quarter price duration)
    upsilon = 0.4;      // Openness parameter
    eta     = 1;        // Substitutability foreign/domestic goods
    
    // Shocks
    rho_a   = 0.80;     // Technology shock persistence
    rho_nu  = 0.00;     // Policy shock persistence (transitory)
    
    // Monetary Policy
    phi_pi  = 2.00;     // Inflation response (strengthened for determinacy)
    phi_y   = 0.15;     // Output gap response
    
    @#if HABIT_FORMATION == 1
        h = 0.70;       // Habit persistence
    @#endif
    
    @#if INTEREST_SMOOTHING == 1
        rho_i = 0.80;   // Interest rate smoothing
    @#endif
    
    @#if INDEXATION == 1
        gamma = 0.25;   // 25% backward-looking inflation
    @#endif
    
    @#if INCOMPLETE_PASSTHROUGH == 1
        alpha_pass = 0.40;  // 40% immediate pass-through
        alpha_m = 0.23;     // Import share in CPI
    @#endif
    
    @#if ER_LEANING == 1
        phi_ds = 0.15;  // Exchange rate leaning
    @#endif
    
    @#if REGIME_DEPENDENT == 1
        // Regime A: Positive rates (2000-2014, 2024-2025)
        phi_pi_A = 2.00;
        phi_ds_A = 0.15;
        // Regime B: Negative rates (2015-2023)
        phi_pi_B = 1.70;
        phi_ds_B = 0.20;
    @#endif
@#else
    // ========================================
    // GALÍ BASELINE CALIBRATION
    // ========================================
    betta   = 0.99;     // Quarterly discount factor
    siggma  = 1;        // Inverse intertemporal elasticity
    varphi  = 5;        // Inverse Frisch elasticity
    alppha  = 1/4;      // Capital share
    epsilon = 9;        // Demand elasticity
    theta   = 3/4;      // Calvo parameter
    upsilon = 0.4;      // Openness parameter
    eta     = 1;        // Substitutability foreign/domestic goods
    
    // Shocks
    rho_a   = 0.9;      // Technology shock persistence
    rho_nu  = 0.5;      // Policy shock persistence
    
    // Monetary Policy
    phi_pi  = 1.5;      // Inflation response
    phi_y   = 0.125;    // Output gap response
    
    @#if HABIT_FORMATION == 1
        h = 0.70;       // Habit persistence
    @#endif
    
    @#if INTEREST_SMOOTHING == 1
        rho_i = 0.80;   // Interest rate smoothing
    @#endif
    
    @#if INDEXATION == 1
        gamma = 0.25;   // 25% backward-looking inflation
    @#endif
    
    @#if INCOMPLETE_PASSTHROUGH == 1
        alpha_pass = 0.40;  // 40% immediate pass-through
        alpha_m = 0.23;     // Import share in CPI
    @#endif
    
    @#if ER_LEANING == 1
        phi_ds = 1.5;  // Exchange rate leaning
    @#endif
    
    @#if REGIME_DEPENDENT == 1
        // Regime A: Positive rates
        phi_pi_A = 2.00;
        phi_ds_A = 0.15;
        // Regime B: Negative rates
        phi_pi_B = 1.70;
        phi_ds_B = 0.20;
    @#endif
@#endif

%----------------------------------------------------------------
% Core model
%----------------------------------------------------------------
model(linear);
#Omega = (1-alppha)/(1-alppha+alppha*epsilon);
#lambda = (1-theta)*(1-betta*theta)/theta*Omega;
#omega = siggma*eta + (1-upsilon)*(siggma*eta-1);
#Phi = 1/(1+upsilon*(omega-1));
#siggma_upsilon = siggma*Phi;
#Gamma_a = (1+varphi)/(siggma_upsilon*(1-alppha)+varphi+alppha);
#kappa_upsilon = lambda*(siggma_upsilon+(varphi+alppha)/(1-alppha));

// Phillips Curve (with optional indexation)
@#if INDEXATION == 1
    [name='Phillips Curve with Indexation']
    pi_h = gamma*pi_h(-1) + (1-gamma)*betta*pi_h(+1) + kappa_upsilon*y_gap;
@#else
    [name='Phillips Curve']
    pi_h = betta*pi_h(+1) + kappa_upsilon*y_gap;
@#endif

// Dynamic IS Curve (with optional habit)
@#if HABIT_FORMATION == 1
    [name='Dynamic IS Curve with Habit']
    y_gap = y_gap(+1) - (1-h)/siggma_upsilon*(i-pi_h(+1)-r_nat);
@#else
    [name='Dynamic IS Curve']
    y_gap = y_gap(+1) - 1/siggma_upsilon*(i-pi_h(+1)-r_nat);
@#endif

// Taylor rule (with optional smoothing, ER leaning, regime-dependence)
@#if REGIME_DEPENDENT == 1
    @#if INTEREST_SMOOTHING == 1
        @#if ER_LEANING == 1
            [name='Taylor Rule - Regime A (smoothing + ER leaning)']
            i = rho_i*i(-1) + (1-rho_i)*(phi_pi_A*pi + phi_y*y_gap + phi_ds_A*d_er) + nu;
        @#else
            [name='Taylor Rule - Regime A (smoothing)']
            i = rho_i*i(-1) + (1-rho_i)*(phi_pi_A*pi + phi_y*y_gap) + nu;
        @#endif
    @#else
        @#if ER_LEANING == 1
            [name='Taylor Rule - Regime A (ER leaning)']
            i = phi_pi_A*pi + phi_y*y_gap + phi_ds_A*d_er + nu;
        @#else
            [name='Taylor Rule - Regime A']
            i = phi_pi_A*pi + phi_y*y_gap + nu;
        @#endif
    @#endif
@#else
    @#if INTEREST_SMOOTHING == 1
        @#if ER_LEANING == 1
            [name='Taylor Rule (smoothing + ER leaning)']
            i = rho_i*i(-1) + (1-rho_i)*(phi_pi*pi_h + phi_y*y_gap + phi_ds*d_er) + nu;
        @#else
            [name='Taylor Rule (smoothing)']
            i = rho_i*i(-1) + (1-rho_i)*(phi_pi*pi_h + phi_y*y_gap) + nu;
        @#endif
    @#else
        @#if ER_LEANING == 1
            [name='Taylor Rule (ER leaning)']
            i = phi_pi*pi_h + phi_y*y_gap + phi_ds*d_er + nu;
        @#else
            [name='Taylor Rule (baseline)']
            i = phi_pi*pi_h + phi_y*y_gap + nu;
        @#endif
    @#endif
@#endif

[name='Natural rate']
r_nat = -siggma_upsilon*Gamma_a*(1-rho_a)*a;

// CPI inflation
@#if INCOMPLETE_PASSTHROUGH == 1
    [name='CPI inflation (with import prices)']
    pi = (1-alpha_m)*pi_h + alpha_m*pi_m;
    
    [name='Import price inflation']
    pi_m = alpha_pass*d_er + (1-alpha_pass)*pi_m(-1);
@#else
    [name='CPI inflation (baseline)']
    pi = pi_h + upsilon*(s-s(-1));
@#endif

// Terms of trade 
[name='Terms of trade']
s = siggma_upsilon*y_gap;

// Exchange rate (implied UIP through other equations)
[name='Exchange rate definition']
s = er - p_h;

[name='Domestic price level']
p_h = p_h(-1) + pi_h;

[name='CPI level']
p = p(-1) + pi;

[name='Exchange rate change']
d_er = er - er(-1);

[name='Monetary policy shock']
nu = rho_nu*nu(-1) - eps_nu;

[name='Technology shock']
a = rho_a*a(-1);

end;

%----------------------------------------------------------------
% Shocks
%----------------------------------------------------------------
shocks;
    var eps_nu = 0.25^2;
end;

steady;
check;

%----------------------------------------------------------------
% IRFs
%----------------------------------------------------------------
@#if INCOMPLETE_PASSTHROUGH == 1
    stoch_simul(order=1, irf=15) pi_h pi pi_m er d_er s i;
@#else
    stoch_simul(order=1, irf=15) pi_h pi er d_er s i;
@#endif