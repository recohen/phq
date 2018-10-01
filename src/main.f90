!*****************************************************************************
module main 
!*****************************************************************************
!
!  Program:    phmd
!
!  Module:     main
!
!*****************************************************************************
!  modules used
   
   use  quantity
   use  parameter

!*****************************************************************************
   
   implicit none

!*****************************************************************************

contains

!*************************************************************************
subroutine control    ( debug )
!*************************************************************************
!
!     Program:          phmd
!
!     Subroutine:       control
!
!**************************************************************************

  implicit none
  
!***************************************************************************
!Shared variables
  
  logical debug 
  
!**************************************************************************
!  Start of subroutine
  
  if( debug ) write(6,'(a)') 'Entering mechanical_prop()...'

   OPEN(unit=11, file='scf.out')
   OPEN(unit=12, file='md.out')
   OPEN(unit=21, file='dyn.out')
  
   call read_scf( debug )
   call read_md( debug )
   ! call properties (debug)
   call read_dyn ( debug )  
   call harmonic_matrix (debug)
   call frequency ( debug )
   call gamma_matrix (debug)
   ! call dynamics_matrix (debug)
   call dynamics_matrix_md (debug)

   close( unit = 11 )
   close( unit = 12 )
   close( unit = 21 ) 

   deallocate ( alat_position )
   deallocate ( cartesian_position )
   deallocate ( alat_md_position )
   deallocate ( cartesian_md_position )
   deallocate ( md_force )
   deallocate ( atom_mass )
   deallocate ( displacement )
   deallocate ( eigen_vector )
   deallocate ( real_vector )
   deallocate ( omega_phonon )
   deallocate ( omega_corr )
   deallocate ( omega_corr_fit )
   deallocate ( omega_mem )
   deallocate ( omega_lorentzian )
   deallocate ( vector_q )

end subroutine control 
!**************************************************************************
subroutine read_scf( debug )
!**************************************************************************
!
!     Purpose:          This subroutine reads in the necessary self-consistent 
!                       input information for the run to proceed. 
!
!**************************************************************************
!  used modules

  use  quantity
  use  text

!**************************************************************************

  implicit none

!**************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!**************************************************************************
!  Local variables

  character ( len = 80 ) :: line
  character ( len = 30 ), dimension ( 10 ) :: words
  character ( len = 30 ), dimension ( 12 ), parameter ::                 &
       command = (/                             &
       'lattice_parameter            ',     & ! 1    
       'natom                        ',     & ! 2    
       'cell_parameters              ',     & ! 3    
       'atomic_positions             ',     & ! 4    
       'dynamics                     ',     & ! 5
       'entering                     ',     & ! 6
       'etot                         ',     & ! 7
       'temperature                  ',     & ! 8
       'axial_optimization           ',     & ! 9
       'md_once                      ',     & ! 10
       'q-points                     ',     & ! 11   
       'reciprocal_axes              '/)      ! 12

  integer :: i, j, j1, j2, j3, n
  integer :: n_integers
  integer :: n_line
  integer :: n_words
  integer :: n_reals
  integer :: n_stress
  integer :: status
  integer :: integer_numbers(10)
  
  double precision :: real_numbers(10)
  double precision :: step1, step2, step3

!**************************************************************************
!  Start of subroutine

  if ( debug ) write(*,*) 'Entering read_input_mechanical()'

  open(unit=11)

  n_line = 0

!  rewind( unit = 11 )
 
  do 
    
     read(11, "(a80)", iostat = status ) line
     
     if ( status < 0 ) exit
     
     n_line = n_line + 1
     
     if ( line(1:1) == '#' ) cycle
     
     call split_line( line, n_words, words,                              &
          n_integers, integer_numbers,                                   &
          n_reals, real_numbers )
    
     if (words(1) == command(1)) then
          
         lattice_parameter  = real_numbers (1)   

     else if (words(1) == command(2)) then

         n_atom1 = integer_numbers (1)  
         n_atoms = n_atom1 * super_size   

         allocate( alat_position( n_atoms, 3 ) )   
         allocate( cartesian_position( n_atoms, 3 ) )   

     else if (words(1) == command(3)) then
        
         do i=1, 3 
            read(11, "(a80)" ) line
            n_line = n_line + 1
            call split_line( line, n_words, words,                        &
                             n_integers, integer_numbers,                 &
                             n_reals, real_numbers )
            if (n_reals < 3) then
                write (6,*) "n_reals < 3" 
            else
                celldm(i,1) = real_numbers(1)  
                celldm(i,2) = real_numbers(2)
                celldm(i,3) = real_numbers(3)
            endif 
         end do 
     
     else if (words(1) == command(4)) then
      
         do i=1, n_atom1
            read(11, "(a80)" ) line
            n_line = n_line + 1
            call split_line( line, n_words, words,                        &
                             n_integers, integer_numbers,                 &
                             n_reals, real_numbers )
            if (n_reals < 3) then
               write (6,*) "(n_reals < 3" 
            else
               alat_position(i,1) = real_numbers(1)   
               alat_position(i,2) = real_numbers(2)
               alat_position(i,3) = real_numbers(3)

               cartesian_position (i,1) =                                 &  
                      alat_position(i,1) *  celldm(1,1) +                 &  
                      alat_position(i,2) *  celldm(2,1) +                 &
                      alat_position(i,3) *  celldm(3,1)                        
               cartesian_position (i,2) =                                 &
                      alat_position(i,1) *  celldm(1,2) +                 &
                      alat_position(i,2) *  celldm(2,2) +                 &
                      alat_position(i,3) *  celldm(3,2)
               cartesian_position (i,3) =                                 &
                      alat_position(i,1) *  celldm(1,3) +                 &
                      alat_position(i,2) *  celldm(2,3) +                 &
                      alat_position(i,3) *  celldm(3,3)
            endif 
         end do 

     else if (words(1) == command(11)) then

        do i=1, super_size 
            read(11, "(a80)" ) line
            n_line = n_line + 1
            call split_line( line, n_words, words,                        &
                             n_integers, integer_numbers,                 &
                             n_reals, real_numbers )

            q_point (i,1) = real_numbers(1)   
            q_point (i,2) = real_numbers(2)   
            q_point (i,3) = real_numbers(3)

        end do

     else if (words(1) == command(12)) then
        
         do i=1, 3 
            read(11, "(a80)" ) line
            n_line = n_line + 1
            call split_line( line, n_words, words,                        &
                             n_integers, integer_numbers,                 &
                             n_reals, real_numbers )
            if (n_reals < 3) then
                write (6,*) "n_reals < 3" 
            else
                recip(i,1) = real_numbers(1)  
                recip(i,2) = real_numbers(2)
                recip(i,3) = real_numbers(3)
            endif 
         end do 

     end if

  end do

  do i =1 , 3
      celldm(i,:) = celldm(i,:) * dble (super(i))   
      alat_position(:,i) = alat_position(:,i) / dble (super(i))   
  end do

  step1 = one / dble (super(1))  
  do j =1, super (1) -1
      do i =1, n_atom1
           alat_position ( i + n_atom1 *j,1 ) =                           &
                                  alat_position ( i,1 ) + step1 * j
           alat_position ( i + n_atom1 *j,2 ) = alat_position ( i,2 ) 
           alat_position ( i + n_atom1 *j,3 ) = alat_position ( i,3 )
      end do
  end do
 
  step2 = one / dble (super(2))
  do j =1, super (2) -1 
       do i =1, n_atom1 * super(1)
           alat_position ( i + n_atom1 * super(1) *j,1 )  =               &
                                  alat_position ( i,1 ) 
           alat_position ( i + n_atom1 * super(1) *j,2 )  =               &
                                  alat_position ( i,2 ) + step2 * j
           alat_position ( i + n_atom1 * super(1) *j,3 )  =               &
                                  alat_position ( i,3 )
       end do
  end do

  step3 = one / dble (super(3))
  do j =1, super (3) -1
       do i =1, n_atom1 * super(1) * super(2)
           alat_position ( i + n_atom1 * super(1) * super(2) *j,1 )  =    & 
                                 alat_position ( i,1 )
           alat_position ( i + n_atom1 * super(1) * super(2) *j,2 )  =    &
                                 alat_position ( i,2 )
           alat_position ( i + n_atom1 * super(1) * super(2) *j,3 )  =    &
                                 alat_position ( i,3 ) + step3 * j
       end do
  end do

  do i = 1, n_atoms 
 
      cartesian_position (i,1) = DOT_PRODUCT (  alat_position(i,:),       &
                                                celldm(:,1) ) 
      cartesian_position (i,2) = DOT_PRODUCT (  alat_position(i,:),       &
                                                celldm(:,2) ) 
      cartesian_position (i,3) = DOT_PRODUCT (  alat_position(i,:),       &
                                                celldm(:,3) )
  end do
 
  do i=1, n_atoms
     cartesian_position(i,1) =  cartesian_position(i,1) * lattice_parameter  
     cartesian_position(i,2) =  cartesian_position(i,2) * lattice_parameter  
     cartesian_position(i,3) =  cartesian_position(i,3) * lattice_parameter

  end do

!
! generate r_point and real_point
!

  i = 0
  r_point = zero 
  do j3=1, super(3) 
      do j2=1, super(2)
           do j1=1, super(1)
                i = i + 1
                r_point (i,1) = dble (j1-1) / super(1)   
                r_point (i,2) = dble (j2-1) / super(2)   
                r_point (i,3) = dble (j3-1) / super(3)
           end do
      end do
  end do

  do i = 1, super_size
     real_point (i,1) = r_point (i,1) * celldm (1,1) + r_point (i,2) * celldm (2,1) + r_point (i,3) * celldm (3,1)
     real_point (i,2) = r_point (i,1) * celldm (1,2) + r_point (i,2) * celldm (2,2) + r_point (i,3) * celldm (3,2)
     real_point (i,3) = r_point (i,1) * celldm (1,3) + r_point (i,2) * celldm (2,3) + r_point (i,3) * celldm (3,3)
  end do

  do i = 1, super_size
     recip_point (i,1) = q_point (i,1) * recip (1,1) + q_point (i,2) * recip (2,1) + q_point (i,3) * recip (3,1)
     recip_point (i,2) = q_point (i,1) * recip (1,2) + q_point (i,2) * recip (2,2) + q_point (i,3) * recip (3,2)
     recip_point (i,3) = q_point (i,1) * recip (1,3) + q_point (i,2) * recip (2,3) + q_point (i,3) * recip (3,3)
  end do

!
! test
!

  write (6, *) "reading scf.out"   

  write (6, *) "cell_parameters"
  do i =1, 3
       write (6,11)  celldm (i,:)
  end do

  write (6, *) "reciprocal_axes"
  do i =1, 3
       write (6,11)  recip (i,:)
  end do

  write (6, *) "r_point"              ! r-points in reduced coordinate
  do i =1, super_size
       write (6,11)  r_point (i,:)
  end do

  write (6, *) "q_point"              ! q-points in reduced coordinate
  do i =1, super_size
       write (6,11)  q_point (i,:)
  end do

  write (6, *) "real_point"           ! r-points in cartesian coordinate in unit of lattice_parameter
  do i =1, super_size
       write (6,11)  real_point (i,:)
  end do

  write (6, *) "recip_point"          ! q-points in cartesian coordinate in unit of 2 pi / lattice_parameter
  do i =1, super_size
       write (6,11)  recip_point (i,:)
  end do

!  do i =1, n_atoms
!        write (6,12) alat_position (i,:), cartesian_position(i,:)
!  end do

 
 11 format(1x,F15.9,1x,F15.9,1x,F15.9,1x)
 12 format(1x,F15.9,1x,F15.9,1x,F15.9,1x,F15.9,1x,F15.9,1x,F15.9,1x)

end subroutine read_scf 
!**************************************************************************
subroutine read_md( debug )
!**************************************************************************
!
!     Purpose:          This subroutine reads in the necessary MD input information 
!                       for the run to proceed. 
!
!**************************************************************************
!  used modules

  use  quantity
  use  text

!**************************************************************************

  implicit none

!**************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!**************************************************************************
!  Local variables

  character ( len = 80 ) :: line
  character ( len = 30 ), dimension ( 10 ) :: words
  character ( len = 15 ), dimension ( 20 ) :: element
  character ( len = 30 ), dimension ( 13 ), parameter ::                 &
       command = (/                             &
       'mass                         ',     & ! 1
       'force                        ',     & ! 2
       'cell_parameters              ',     & ! 3
       'atomic_positions             ',     & ! 4
       'md_step                      ',     & ! 5
       'temperature                  ',     & ! 6
       'etot                         ',     & ! 7
       'tem                          ',     & ! 8
       'nstep                        ',     & ! 9
       'total_step                   ',     & ! 10 
       'types                        ',     & ! 11
       'kinetic_energy               ',     & ! 12
       'pressure                     '/)      ! 13   

  integer :: i, ii, iii, j, n  
  integer :: n_integers
  integer :: n_line
  integer :: n_words
  integer :: n_reals
  integer :: n_stress
  integer :: status
  integer :: md_step 
  integer :: actual_step
  integer :: i_species
  integer :: bool
  integer :: integer_numbers(10)
 
  double precision :: real_numbers(10)
  double precision, allocatable :: msd_ave (:)
  double precision, allocatable :: n_atom_internal (:)
  double precision, allocatable :: system (:,:)
  double precision, allocatable :: pressure (:)
  double precision, allocatable :: msd (:)

!**************************************************************************
!  Start of subroutine

  if ( debug ) write(*,*) 'Entering read_input_mechanical()'

  open(unit=13,file='temperature.out')
  open(unit=14,file='msd.out')

  ii = 0
  md_step = 0
  n_atom_internal = 0
  system = 0
  i_species = 0
  
  element = 'null'
 
  open(unit=12)

  n_line = 0

!  rewind( unit = 12 )

  do 
    
     read(12, "(a80)", iostat = status ) line
  
     if ( status < 0 ) exit
     
    n_line = n_line + 1
    
    if ( line(1:1) == '#' ) cycle
    
    call split_line( line, n_words, words,                              &
         n_integers, integer_numbers,                                   &
         n_reals, real_numbers )

    if (words(1) == command(11)) then

        n_species = integer_numbers (1)

    else if (words(1) == command(10)) then   

        n_step = integer_numbers (1)        

        allocate( alat_md_position( n_step, n_atoms, 3 ) )   
        allocate( cartesian_md_position( n_step, n_atoms, 3 ) )   
        allocate( displacement ( n_step, n_atoms, 3 ) )   
        allocate( md_force( n_step, n_atoms, 3 ) )   
        allocate( temperature (n_step))   
        allocate( kinetic_energy (n_step))   
        allocate( pressure (n_step))   
        allocate( total_energy (n_step))   
        allocate( atom_mass (n_atoms) )
        allocate( msd (n_atoms))
        allocate( system (n_species, n_atoms))
        allocate( msd_ave (n_species))
        allocate( n_atom_internal (n_species))

    else if (words(1) == command(1)) then

        ii = ii + 1
        atom_mass(ii) = real_numbers(1)   
        
        bool = 1

        do iii = 1, i_species + 1
            if (words(2) == element(iii)) then
                n_atom_internal (iii) = n_atom_internal (iii) + 1   
                system (iii,ii) = 1 
                bool = bool * 0
            end if 
        end do

        if (bool == 1) then
            i_species = i_species + 1
            element(i_species) = words(2)
            n_atom_internal (i_species) = n_atom_internal (i_species) + 1   
            system (i_species,ii) = 1
        end if
 
    else if (words(1) == command(5)) then

        md_step = md_step + 1   

    else if (words(1) == command(6)) then

        temperature(md_step) = real_numbers  (1)  

    else if (words(1) == command(12)) then

        kinetic_energy (md_step) = real_numbers  (1)   

    else if (words(1) == command(13)) then

        pressure (md_step) = real_numbers  (1)   

    else if (words(1) == command(7)) then

        total_energy(md_step) = real_numbers  (1)  

    else if (words(1) == command(4)) then
     
        do i=1, n_atoms
           read(12, "(a80)" ) line
           n_line = n_line + 1
           call split_line( line, n_words, words,                        &
                            n_integers, integer_numbers,                 &
                            n_reals, real_numbers )
           if (n_reals < 3) then
             write (6,*) "(n_reals < 3" 
           else
              alat_md_position(md_step,i,1) = real_numbers(1)   
              alat_md_position(md_step,i,2) = real_numbers(2)
              alat_md_position(md_step,i,3) = real_numbers(3)

              cartesian_md_position ( md_step,i,1 ) =                    &   
                     alat_md_position( md_step,i,1 ) *  celldm(1,1) +    &
                     alat_md_position( md_step,i,2 ) *  celldm(2,1) +    &
                     alat_md_position( md_step,i,3 ) *  celldm(3,1)         
              cartesian_md_position ( md_step,i,2 ) =                    &
                     alat_md_position( md_step,i,1 ) *  celldm(1,2) +    &
                     alat_md_position( md_step,i,2 ) *  celldm(2,2) +    &
                     alat_md_position( md_step,i,3 ) *  celldm(3,2)
              cartesian_md_position ( md_step,i,3 ) =                    &
                     alat_md_position( md_step,i,1 ) *  celldm(1,3) +    &
                     alat_md_position( md_step,i,2 ) *  celldm(2,3) +    &
                     alat_md_position( md_step,i,3 ) *  celldm(3,3)

           endif 
        end do 

    else if (words(1) == command(2)) then

        do i=1, n_atoms
            read(12, "(a80)" ) line
            n_line = n_line + 1
            call split_line( line, n_words, words,                        &
                             n_integers, integer_numbers,                 &
                             n_reals, real_numbers )
            if (n_reals < 3) then
              write (6,*) "(n_reals < 3"
            else
               md_force(md_step,i,1) = real_numbers(1)   
               md_force(md_step,i,2) = real_numbers(2)
               md_force(md_step,i,3) = real_numbers(3)
            endif
         end do 

    end if

    if ( md_step > n_step_use + 3 )  exit   

  end do

  n_step = md_step   

  if ( ( n_step - n_step_use ) < 3 ) then
      n_step_use = n_step  - 3   
  end if

 
  do j = 1, md_step -1   
 
     do i = 1, n_atoms

        cartesian_md_position ( j,i,1 ) =                          &
            cartesian_md_position ( j,i,1 ) * lattice_parameter        
        cartesian_md_position ( j,i,2 ) =                          &
            cartesian_md_position ( j,i,2 ) * lattice_parameter
        cartesian_md_position ( j,i,3 ) =                          &
            cartesian_md_position ( j,i,3 ) * lattice_parameter

     end do

     do i = 1, n_atoms
 
        displacement ( j,i,1 ) = cartesian_md_position(j,i,1) -           &   
                             cartesian_position(i,1) 
        displacement ( j,i,2 ) = cartesian_md_position(j,i,2) -           &
                             cartesian_position(i,2)
        displacement ( j,i,3 ) = cartesian_md_position(j,i,3) -           &
                             cartesian_position(i,3)

     end do
     
  end do

!
! MSD
!

  write(13,*) "md_step = ", md_step - 1   
  msd = zero
  do j=1, md_step - 1   
      do i = 1, n_atoms
           msd (i) = msd (i) +   (                                        &   
                       displacement ( j,i,1 )**two +                      &
                       displacement ( j,i,2 )**two +                      &
                       displacement ( j,i,3 )**two )
      end do 
      write(13,19) j, pressure (j), temperature(j),                       &
                   kinetic_energy(j), total_energy(j)
  end do 

  msd_ave = zero
  do j = 1, n_species
     do i = 1, n_atoms
        msd_ave (j) = msd_ave (j) + msd (i) * system (j,i) /dble (md_step-1)   
     end do
     msd_ave (j) = msd_ave (j) / dble (n_atom_internal(j))  

     write(14,21,advance='NO') msd_ave (j)

  end do


  do j=1, md_step
       do i = 1, n_atoms
            if(displacement ( j,i,1 )> 0.8) then   
                 write(13,*) "folding: ",i
            end if
            if(displacement ( j,i,2 )> 0.8) then
                  write(13,*) "folding: ",i
            end if
            if(displacement ( j,i,3 )> 0.8) then
                 write(13,*) "folding: ",i
            end if
       end do
  end do

  11 format(1x,F15.9,1x,F15.9,1x,F15.9,1x) 
  19 format(1x,i8,1x,F10.3,1x,F12.5,1x,F14.8,1x,F18.8,1x)
  20 format(1x,i8,1x)
  21 format(1x,f10.6,1x)

  close(13)
  close (14)

  deallocate (pressure)
  deallocate (msd)
  deallocate (system)
  deallocate (msd_ave)
  deallocate (n_atom_internal)

end subroutine read_md
!**************************************************************************
subroutine properties ( debug ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains C_v from MD simulations 
!                            
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!*************************************************************************
!  Local variables
  
  integer :: i, j, k

  double precision :: energy_k_square, energy_k, energy_tot_average, energy_p
  double precision :: delta_energy_k_square
  double precision :: temperature_average
  double precision :: heat_capacity

!*************************************************************************
!  Start of subroutine

  OPEN(unit=61, file='properties.out')
 
!
! calculate the heat capacity -- Cv via heat flutuation
!
  energy_k_square = 0.0d0
  energy_k = 0.0d0
  energy_tot_average = 0.0d0
  temperature_average = 0.0d0
  do k = 1, n_step_use   

      energy_k_square = energy_k_square + kinetic_energy (k)**2
      energy_k = energy_k + kinetic_energy (k)
      energy_tot_average = energy_tot_average + total_energy (k)
      temperature_average = temperature_average + temperature (k)  
 
  end do 

  energy_k_square = energy_k_square / dble (n_step_use)   
  energy_k = energy_k / dble (n_step_use)   
  energy_tot_average = energy_tot_average /  dble (n_step_use)   
  temperature_average = temperature_average / dble (n_step_use)   

  energy_p = energy_tot_average - energy_k   
  delta_energy_k_square = energy_k_square - energy_k**2   

  heat_capacity = 1.5d0 / ( one -                                         &   
             delta_energy_k_square / ( temperature_average * energy_k ) * &  
             13.60569253 / boltzmann_k )                                      

  write(61,*) "n_step_use, temperature_average, energy_p, heat_capacity"
  write(61,11)n_step_use, temperature_average, energy_p, heat_capacity 

  close (61)

  11 format(1x,i8,1x,f20.9,1x,f20.10,1x,f10.5,1x)

  deallocate ( kinetic_energy )
  deallocate ( total_energy )
  deallocate ( temperature )
  
end subroutine properties 
!**************************************************************************
subroutine read_dyn ( debug )
!**************************************************************************
!
!     Purpose:          This subroutine reads in the necessary harmonic phonon
!                       input information for the run to proceed. 
!
!**************************************************************************
!  used modules

  use  quantity
  use  text

!**************************************************************************

  implicit none

!**************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!**************************************************************************
!  Local variables

  character ( len = 80 ) :: line
  character ( len = 30 ), dimension ( 10 ) :: words
  character ( len = 30 ), dimension ( 2 ), parameter ::                 &
       command = (/                             &
       'q                            ',     & ! 1
       'freq                         '/)      ! 2

  integer :: i, j, k, n
  integer :: n_integers
  integer :: n_line
  integer :: n_words
  integer :: n_reals
  integer :: n_stress
  integer :: status 
  integer :: md_step 
  integer :: n_omega 
  integer :: integer_numbers(10)
  
  double precision :: real_numbers(10)
  double precision :: orthog, imagine
  double precision :: theta

  complex ( kind = kind( 0.0d0 ) ) :: phase 
  complex ( kind = kind( 0.0d0 ) ), allocatable :: temp_vector(:,:)

!**************************************************************************
!  Start of subroutine

  if ( debug ) write(*,*) 'Entering read_input_mechanical()'

  OPEN(unit=21, file='dyn.out')
  OPEN(unit=22, file='vector.out')
  OPEN(unit=23, file='vector_q.out')
  
  allocate( vector_q (n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( eigen_vector ( n_atoms *3, n_atoms *3 ) )
  allocate( real_vector ( n_atoms *3, n_atoms *3 ) )
  allocate( omega_phonon ( n_atoms *3 ) )
  allocate( temp_vector ( n_atoms *3, n_atoms *3 ) )

  n_line = 0

  n_omega =0

!  rewind( unit = 21 )
 
  do 
    
     read(21, "(a80)", iostat = status ) line
     
     if ( status < 0 ) exit
     
     n_line = n_line + 1
     
     if ( line(1:1) == '#' ) cycle
     
     call split_line( line, n_words, words,                              &
          n_integers, integer_numbers,                                   &
          n_reals, real_numbers )

     if (words(1) == command(2)) then
     
         n_omega =  n_omega + 1   
         omega_phonon (n_omega) = real_numbers (1)   
 
         do i=1, n_atom1 * 3
            read(21, "(a80)" ) line
            n_line = n_line + 1
            call split_line( line, n_words, words,                        &
                             n_integers, integer_numbers,                 &
                             n_reals, real_numbers )
            if (n_reals < 2) then
               write (6,*) "n_reals < 2" 
            else
               temp_vector ( i, n_omega ) = CMPLX (                       &   
                                   real_numbers(1), real_numbers(2)       &   
                                                    )                         
            endif                                                             
         end do 

     end if

  end do

!
! super cell eigenvector
!

  do j =1, super_size 
     do k = 1, n_atom1 *3
          do i =1, n_atom1 * 3
              do n = 1, super_size
                   theta = two * pi *                                     &
                           DOT_PRODUCT (recip_point (j,:), real_point (n,:) )
                   phase = CMPLX ( COS (theta), SIN (theta) )   
                   eigen_vector                                           &   
                     ( i + (n-1) *n_atom1 *3, k + (j-1) *n_atom1 *3 ) =   &   
                         temp_vector ( i, k +(j-1) *n_atom1 *3 ) * phase   
              end do                                                                         
          end do
     end do
  end do

!
! achieve the orthogonality. atom_mass is the atomic mass of atom 
!

  do i = 1,  n_atoms * 3 
      do k=1, n_atoms
          eigen_vector (3*k-2, i) =  eigen_vector (3*k-2, i) *            &   
                            CMPLX ( sqrt ( atom_mass(k) ) ,zero )
          eigen_vector (3*k-1, i) =  eigen_vector (3*k-1, i) *            &
                            CMPLX ( sqrt ( atom_mass(k) ), zero )
          eigen_vector (3*k, i) =  eigen_vector (3*k,  i ) *              &
                            CMPLX ( sqrt ( atom_mass(k) ), zero )
      end do
  end do

!
! normalize the eigenvectors
!
  do i = 1,  n_atoms * 3 
      orthog = DBLE ( DOT_PRODUCT (  (eigen_vector (:,i) ),             &
                                eigen_vector (:,i) ) )

      eigen_vector (:,i) = eigen_vector (:,i) / sqrt (orthog)  
 
  end do

  real_vector = DBLE ( eigen_vector )  


!
!  normalized eigenvector of the primitive cell
!

  do j = 1, super_size
       do i = 1, n_atom1 *3
            do k = 1, n_atom1 *3
                 vector_q (k,i,j) =                                       &   
                         temp_vector ( k, i + n_atom1 *3 * (j-1) )
            end do
       end do
  end do

  do j = 1, super_size
       do i = 1, n_atom1 *3
            do k = 1, n_atom1 
                 vector_q ( 3*k-2,i,j ) = vector_q ( 3*k-2,i,j ) *        &   
                                CMPLX ( sqrt (  atom_mass (k) ), zero )
                 vector_q ( 3*k-1,i,j ) = vector_q ( 3*k-1,i,j ) *        &
                                CMPLX ( sqrt (  atom_mass (k) ), zero )
                 vector_q ( 3*k,i,j ) = vector_q ( 3*k,i,j ) *            &
                                CMPLX ( sqrt (  atom_mass (k) ), zero )

 
            end do
       end do
  end do

  do j = 1, super_size
       do i =1, n_atom1 *3
            orthog =  DBLE ( DOT_PRODUCT (                                &
                            vector_q (:,i,j), vector_q (:,i,j) ) )

            vector_q (:,i,j) = vector_q (:,i,j) / sqrt (orthog)  
       end do
  end do


!
!  check the orthogonality
!

   do j = 1, super_size
      write (6,*) super_size," =", j
      do i = 1, n_atom1 * 3
          orthog = DBLE (dot_product (vector_q (:,i,j), vector_q (:,6,j)) )   
 
          write (6,13) i, orthog , omega_phonon (i + (j -1) * n_atom1 *3)
      end do
  end do

!
! output vectors
!

  write(6,*) "reading dyn"
  do i =1, n_atoms * 3
       write(22,*) "mode = ", i
       do j = 1, n_atoms * 3
            write (22,14) eigen_vector (j,i)   
       end do
  end do

  do j = 1, super_size
       write (23,*) "q", j
      do i = 1, n_atom1 *3
          write (23,*) "mode", i
          do k = 1, n_atom1 *3
               write (23,14) vector_q (k,i,j)   
          end do
      end do
  end do 

  13 format(1x,i9,1x,f25.15,1x,f25.15,1x)
  11 format (1x,f15.6,1x,f15.6,1x)
  12 format (1x,i5,1x,i5,1x,f15.10,1x,f15.10,1x)
  14 format (1x,f20.15,1x,f20.15,1x)

  deallocate ( temp_vector)

  close (22)
  close (23)

end subroutine read_dyn

!**************************************************************************
subroutine harmonic_matrix ( debug ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains the dynamics matrix from omega. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!*************************************************************************
!  Local variables
   
  integer :: i, j, k, u

  double precision, allocatable :: dynamics_matrix_q ( :,: ) 
  double precision, allocatable :: diagonal_matrix_q ( :,: )
  double precision, allocatable :: matrix_q ( :,: )
  double precision, allocatable :: omega_dynmat (:)

!*************************************************************************
!  Start of subroutine

  allocate( dynamics_matrix_q (n_atoms *3, n_atoms *3) )
  allocate( diagonal_matrix_q (n_atoms *3, n_atoms *3) )
  allocate( matrix_q (n_atoms *3, n_atoms *3)  )
  allocate ( omega_dynmat (n_atoms *3 ) )

  OPEN(unit=41, file='harmonic_matrix.mat')
 
  do i = 1, n_atoms * 3
       do j = 1, n_atoms * 3
             diagonal_matrix_q (i,j) = zero 
       end do
  end do

  omega_dynmat  =  omega_phonon  

  do i = 1, n_atoms * 3 
 
       diagonal_matrix_q (i,i ) = omega_dynmat (i)**2                     &   
          / ( ryd/amu/adu/adu ) *( thertz * two* pi )**2
 
  end do

  do i = 1, n_atoms * 3
      do j = 1, n_atoms * 3
       
          matrix_q ( i,j )  =  dot_product ( real_vector (i,:),           &   
                              diagonal_matrix_q (:,j) )         
                
      end do
  end do
 
  do i = 1, n_atoms * 3
      do j = 1, n_atoms * 3
        
          dynamics_matrix_q ( i,j )  =  dot_product ( matrix_q (i,:),     &   
                               real_vector (j,:) )
            
      end do
  end do

  do k = 1, 3
  do u = 1, 3 
      do i = 1, n_atoms 
      do j = 1, n_atoms 

           dynamics_matrix_q ( 3*i -3 + k, 3*j-3 + u ) =                  &  
                dynamics_matrix_q ( 3*i -3 + k, 3*j-3 + u ) *             &
                 sqrt ( atom_mass (i) * atom_mass (j) )

      end do
      end do
  end do
  end do

  write (41,11)  n_atoms, n_atoms
  
  do i = 1, n_atoms
  do j = 1, n_atoms

      write (41,11)  i, j

      do k = 1, 3
    
           write (41,12)  dynamics_matrix_q ( 3*i-3+k, 3*j-3+1 ),         &
                          dynamics_matrix_q ( 3*i-3+k, 3*j-3+2 ),         &
                          dynamics_matrix_q ( 3*i-3+k, 3*j-3+3 )  
      end do
  end do
  end do
  
  ! call harmonic_force (debug, dynamics_matrix_q)

  close (41)

  11 format(1x,i5,1x,i5,1x)
  12 format(1x,f15.10,2x,f15.10,2x,f15.10,1x)

  deallocate (dynamics_matrix_q)
  deallocate (diagonal_matrix_q)
  deallocate (matrix_q)
  deallocate (omega_dynmat)

end subroutine harmonic_matrix 
!**************************************************************************
subroutine harmonic_force ( debug, dynamics_matrix_q ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains the dynamics matrix from omega. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug
  
  double precision, intent (IN) :: dynamics_matrix_q (n_atoms*3,n_atoms*3 )

!*************************************************************************
!  Local variables
    
  integer :: i, j, k, u

  double precision :: diff, force0
  double precision, allocatable :: displace ( :,: ) 
  double precision, allocatable :: force_h ( :,: )

!*************************************************************************
!  Start of subroutine

  OPEN(unit=42, file='harmonic_force.mat')

  allocate( displace (n_step, n_atoms *3) )
  allocate( force_h (n_step, n_atoms *3) )

  do k = 1, n_step_use
      do j =1, n_atoms

          displace ( k,j*3-2 ) =  displacement ( k,j,1 )
          displace ( k,j*3-1 ) =  displacement ( k,j,2 ) 
          displace ( k,j*3   ) =  displacement ( k,j,3 )   

      end do

      do i = 1, n_atoms * 3
          force_h (k,i ) = DOT_PRODUCT ( dynamics_matrix_q (i,:) ,        &   
                                         displace (k,:) )
      end do

  end do

  diff = zero
  force0 = zero

  do k =1, n_step_use
       do i = 1, n_atoms
           diff = diff + (                                                &   
                         ( force_h (k,3*i-2) + md_force (k,i,1) )**two +  &   
                         ( force_h (k,3*i-1) + md_force (k,i,2) )**two +  &
                         ( force_h (k,3*i  ) + md_force (k,i,3) )**two )
           force0 = force0 + (                                            &   
                             force_h ( k,3*i-2 )**two +                   &
                             force_h ( k,3*i-2 )**two +                   &
                             force_h ( k,3*i-2 )**two ) 
       end do
  end do

  write (42,*) "diff / force0 = "
  write (42,12) diff / force0   

  11 format(1x,i5,1x,i5,1x)
  12 format(1x,f15.10,1x)

  close (42)

  deallocate (displace)
  deallocate (force_h)  

end subroutine harmonic_force 
!**************************************************************************
subroutine frequency ( debug ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains omega from MD simulations. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!*************************************************************************
!  Local variables
  
  integer :: i, j, k 

  double precision :: velocity_real
  double precision, allocatable :: mass_extension (:)
  double precision, allocatable :: displace_extension(:,:)

  complex ( kind = kind( 0.0d0 ) ), allocatable :: velocity_0 (:,:)
  complex ( kind = kind( 0.0d0 ) ), allocatable :: velocity (:,:)

!*************************************************************************
!  Start of subroutine

  allocate( omega_corr_fit (n_atoms * 3) )
  allocate( omega_corr (n_atoms * 3) )
  allocate( omega_mem (n_atoms * 3) )
  allocate( omega_lorentzian (n_atoms * 3) )
  allocate( mass_extension ( n_atoms * 3 ) )
  allocate( displace_extension ( n_step,n_atoms * 3 ) )
  allocate( velocity ( n_step, n_atoms * 3 ) )
  allocate( velocity_0 ( n_step, n_atoms * 3 ) )

  OPEN(unit=31, file='frequency.freq')

  omega_corr_fit = zero
  omega_corr = zero

!
! calculate the normal coordinates and normal force
!
  do k = 1, n_step 
     
      do j = 1, n_atoms
            
           mass_extension ( j*3-2 )  =  atom_mass (j)
           mass_extension ( j*3-1 )  =  atom_mass (j)
           mass_extension ( j*3   )  =  atom_mass (j)   
         
           displace_extension ( k,j*3-2 ) = displacement ( k,j,1 ) *      &
                      sqrt ( atom_mass (j) )
           displace_extension ( k,j*3-1 ) = displacement ( k,j,2 ) *      &
                      sqrt ( atom_mass (j) ) 
           displace_extension ( k,j*3   ) = displacement ( k,j,3 ) *      &   
                      sqrt ( atom_mass (j) )

      end do

  end do 


!
!  calculate velocity
!

  do k = 3, n_step
      do i = 1, n_atoms * 3 

           velocity_real  =                                               &   
              ( displace_extension (k,i) - displace_extension (k-2,i) )   &
                 /d_t / two   ! d_t: MD time length

           velocity_0 (k-2,i) = CMPLX ( velocity_real, zero  )  

      end do
  end do 

!
! calculate normal velocity
!

  do k =1, n_step -2
      do i =1, n_atoms * 3
           velocity (k,i) = DOT_PRODUCT ( CONJG( eigen_vector (:,i) ),             &   
                            velocity_0 (k,:) )                      
      end do
  end do

!
! calculation of velocity correlation
!

   call correlation ( debug, velocity, n_step_use, n_corr )

!
!  calculate temperature of each mode
!
   
   ! call equipartition ( debug, velocity )

!
! calculate frequency by maxium entropy method
!

   call maximum_entropy ( debug, velocity )

!
!  output
!

  do j = 1, n_atoms * 3

     write (31,12) j,                                                     &   
                   omega_phonon (j) * thz_to_cm,                      &   ! harmonic phonon frequency
                   omega_corr_fit (j),                                &   ! curve fitted phonon frequency
                   omega_corr (j),                                    &   ! fourier transformed phonon frequency
                   omega_mem (j)                                          ! maximum entropy method phonon frequency

  end do

  close (31)

  12 format(1x,i4,1x,f15.6,1x,f15.6,1x,f15.6,1x,f15.6,1x)

  deallocate (velocity_0) 
  deallocate (mass_extension)
  deallocate (displace_extension)
  deallocate (velocity)


end subroutine frequency 
!**************************************************************************
subroutine equipartition ( debug, velocity ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains e_kinetic from MD simulations. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

  complex (kind =kind(0.0d0)),intent (IN) :: velocity (n_step, n_atoms *3)

!*************************************************************************
!  Local variables
  
  integer :: i, j, k  

  double precision, allocatable ::  e_kinetic (:)

!*************************************************************************
!  Start of subroutine

  allocate( e_kinetic (n_atoms * 3) )

  OPEN(unit=62, file='equipartition.out')
  
  do i = 1, n_atoms *3 

      e_kinetic (i) = zero

      do k = 3, n_step_use

          e_kinetic ( i ) =  e_kinetic ( i ) +                            &   
                DBLE ( CMPLX ( velocity(k-2,i) ) * velocity(k-2,i) ) *    &
                amu * adu**2 / atu**2 / boltzmann_k

      end do
      e_kinetic (i) = e_kinetic (i) / dble (n_step_use-2)  

      write (62,11) i, e_kinetic (i)

  end do
 

  11 format(1x,i8,1x,f20.6,1x)

  close (62)

  deallocate (e_kinetic) 
 
end subroutine equipartition 
!**************************************************************************
subroutine correlation ( debug, a, na, ncorr ) 
!**************************************************************************
!
!     Purpose:  This subroutine computes the velocity correlation function. 
! 
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug
  
  integer, intent (IN) :: na 
  integer, intent(in) :: ncorr  ! limit of the correlation time   

  complex ( kind = kind( 0.0d0 ) ), intent (IN) :: a( n_step, n_atoms * 3)
   

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n
  integer :: first, period
  integer, allocatable :: n_win_mode (:)

  double precision :: max, max_0
  double precision, allocatable :: corr (:,:)

!*************************************************************************
!  Start of subroutine

   OPEN(unit=63, file='corr.vaf')

   allocate ( corr ( ncorr, n_atoms * 3 ) )
   allocate ( n_win_mode ( n_atoms * 3 ) )

!
!  correlation function
!

   do k = 1, n_atoms * 3
      corr (:,k) = zero
      do i = 1, na - ncorr + 1     ! loop over starting point        
          do j = 1, ncorr            ! loop over correlation time       
              corr(j,k) = corr(j,k) +                                     &
                          DBLE ( CONJG ( a(i,k) ) * a(i+j-1, k) )  
          end do                               
      end do
      corr (:,k) = corr(:,k) / DBLE ( na - ncorr + 1 )   

   end do

!
!  correlation decay  to 0.65 in amplitude. 
!
 
   do k = 1, n_atoms * 3
       max_0 = corr (1,k)
       first = 0
       max = max_0
       n_win_mode (k) = ncorr   
       do  i = 2,  ncorr 
           if ( corr (i,k ) < corr ( i-1,k ) ) then 
               first = first + 1   
               if (first == 1) then
                   if (max < max_0 * 0.5d0 ) then   
                       n_win_mode (k) = i   
                       exit
                   end if
               end if
               max = corr (i,k)   
           else
               first = 0
               max = corr (i,k)    
           end if
       end do

       period = one / (omega_phonon (k) * thertz) / atu / d_t   
       write (6,*) k, "period= ", period

       if (n_win_mode (k) < period * 4 ) then   
             n_win_mode (k) = period * 4 
       end if
       if (n_win_mode (k) > period * 15 ) then
            n_win_mode (k) = period * 15
       end if
       if (n_win_mode (k) > ncorr) then
           n_win_mode (k) = ncorr
       end if

   end do
 
!
! output
!

   do j = 1, ncorr
        write (63,11,advance='NO') j
        do i = 1, n_atoms*3
            write (63,12,advance='NO')  corr (j,i) /                      &   
                  e_mass * 27.2114 /two / boltzmann_k / two
        end do
        write(63,*)
   end do

   do k =1, n_atoms * 3
      write (6,*) k,"n_window= ", n_win_mode (k)  
   end do

!
!  Fit the correlation function
!

   call correlation_fit ( debug, ncorr, corr, n_win_mode )

!
! Fourier transform
! 
   
   call corr_fourier ( debug, ncorr, corr, n_win_mode ) 


   11 format(1x,i8,1x)
   12  format(1x,f20.10,1x)

   deallocate (n_win_mode)
   deallocate (corr)

   close (63)

end subroutine correlation 
!**************************************************************************
subroutine correlation_fit ( debug, ncorr, corr, n_win ) 
!**************************************************************************
!
!   Purpose:    This subroutine fits the correlation function accrording to 
!               Tao Sun's Paper PRB 2010. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

  integer, intent (IN) :: ncorr
  integer, intent (IN) :: n_win ( n_atoms * 3 )

  double precision, intent (IN) :: corr ( ncorr, n_atoms * 3)

!*************************************************************************
!  Local variables
  
  integer :: a, b, c, i, j, m, k, n, v

  double precision :: omega_0, d_omega, omega_new
  double precision :: am_0, am, am_new, tau, tau_0, tau_new
  double precision :: x, err, err1,d_x,d_am,d_tau 
  double precision :: million
  double precision :: fit,t
  double precision, allocatable :: result (:,:)
  double precision, allocatable :: ammode (:)
  double precision, allocatable :: taumode (:)

!*************************************************************************
!  Start of subroutine

  allocate ( ammode ( n_atoms * 3 ) )
  allocate ( taumode ( n_atoms * 3 ) )
  allocate ( result (ncorr, n_atoms * 3 ) )

  OPEN (unit = 66, file='corr_fit.vaf')
  OPEN (unit = 69, file='tau_fit.tau')

  a = 20
  b = 20 
  c = 40

  result = zero
  million = 1000000.0d0

  do i = 1, n_atoms *3 

      omega_0 = two * pi * omega_phonon (i) * thertz   
      am_0 = corr (1,i) * million   
      tau_0 = temperaturemd / dble (25.0) / thz_to_cm * thertz   
!!! Note: temperaturemd is a parameter should be adjusted at different pressure         
      d_omega = three * pi * two / thz_to_cm  * thertz

      err1 = 10000000.0d0

      do j = 1, 11
         
          d_am = am_0 / dble (10.0d0) / dble (1.5**dble(j-1))  
          d_x = d_omega / dble ( 1.5**dble(j-1) )
          d_tau = two* three / thz_to_cm * thertz / dble (1.5**dble(j-1))

          do m = 1, a
          do n = 1, b
          do v = 1, c

              am = am_0 + dble (m-a/2) * d_am   
              x = omega_0 + dble (n -b/2) * d_x   
              tau = tau_0 + dble (v-c/2) * d_tau    
 
              err = zero

              do k = 1, n_win (i)   
                  t = d_t * k* atu
                  fit = am * COS ( x * t ) / EXP ( tau * t )  
                  err = err +  ( fit - million * corr (k,i) )**2   
              end do

              if (err < err1) then   
                   err1 = err
                   am_new = am
                   omega_new = x
                   tau_new = tau 
              end if 

           end do
           end do
           end do

           am_0 = am_new  
           omega_0 = omega_new
           tau_0 = tau_new

      end do

      omega_corr_fit (i) = omega_0 /thertz/two/pi  * thz_to_cm   
      ammode (i) = am_0   
      taumode (i) = tau_0  

      write (6,*) "omega_corr_fit ", i,omega_corr_fit (i)  

  end do



  do i = 1, 3
      omega_corr_fit (i) = omega_phonon (i) * thz_to_cm   
  end do

  do i = 1, n_atoms * 3
!      do k =1, n_win (i) 
      do k =1, ncorr 
         t = d_t * k * atu
         result (k,i) = ammode (i) *                                      &
             COS( omega_corr_fit(i)/thz_to_cm *thertz * two * pi * t ) /  &
             EXP ( taumode (i) * t )
      end do
  end do


  do i= 1, n_atoms * 3
      write (69,12) i, taumode (i) * thz_to_cm / thertz   
  end do

  do k =1, ncorr
     write (66,11,advance='NO') k
     do i = 1, n_atoms *3
          write (66,13,advance='NO') result (k,i) / million /             &
                       e_mass * 27.2114 /two / boltzmann_k / two
     end do
     write (66,*)
  end do

!
! frouier transform of corr_fit
!

 ! call corr_fit_fourier (debug)



  11  format (1x,i8,1x)
  13  format (1x,f20.10,1x)
  12  format (1x,i8,1x,f20.10,1x)

  close (66)
  close (69)

  deallocate (taumode)
  deallocate (ammode)
  deallocate (result)

end subroutine correlation_fit 
!**************************************************************************
subroutine corr_fourier ( debug, ncorr, corr, n_win ) 
!**************************************************************************
!
!   Purpose: This subroutine performs Fourier transfrom of correlation function.  
! 
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug
  
  integer, intent (IN) :: ncorr
  integer, intent (IN) :: n_win ( n_atoms * 3 )

  double precision, intent (IN) :: corr ( ncorr, n_atoms * 3)

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n
  integer :: location, first, period
  integer,allocatable :: n_freq (:)

  double precision :: theta, f_omega_max
  double precision, allocatable :: d_omega (:)
  double precision, allocatable :: window (:,:)  
  double precision, allocatable :: f_corr_module (:,:)

  complex ( kind = kind( 0.0d0 ) ) :: phase
  complex ( kind = kind( 0.0d0 ) ) :: f_corr

!*************************************************************************
!  Start of subroutine

   OPEN(unit=64, file='corr_fourier.vaf')

   allocate ( window (ncorr,n_atoms * 3) )
   allocate ( f_corr_module ( n_step, n_atoms * 3 ) )
   allocate ( n_freq ( n_atoms * 3 ) )
   allocate ( d_omega ( n_atoms * 3 ) )

!
! window function
!
   window = zero
   do k =1, n_atoms * 3
      do i = 1, n_win (k)   
         window (i,k) =                                                   &   
            SIN( pi * dble (n_win (k) -i)/dble (2*n_win (k) -1) )**2

      end do
   end do

  window = one

!
! fourier transform
!

   f_corr_module = zero 
   do k =1,  n_atoms * 3

      write (6,*) k

      d_omega (k) = two * pi / d_t / dble (n_win (k) ) / dble (20.0d0)
      n_freq (k) =  n_win (k) * three  

      do j = 1, n_freq (k) 

          f_corr = CMPLX (zero, zero)

          do i = 1, n_win (k)   

               window (i,k) = one   

               theta = d_omega (k) * DBLE (j) * dble (i) * d_t   
               phase = CMPLX ( COS( theta ), SIN ( theta ) )   

               f_corr = f_corr +                                          &   
                        CMPLX ( corr (i,k) * window (i,k), zero  ) * phase   

          end do        
 
          f_corr_module ( j,k ) =                                         &  
              ( ( DBLE ( f_corr ) )**2 + ( AIMAG ( f_corr ) )**2 ) /      &  
              dble ( n_win (k) )   

      end do
   end do

   do k =1,  n_atoms * 3
   
      f_omega_max = zero
      do j =1, n_freq (k)
           if ( f_corr_module ( j,k ) > f_omega_max ) then
                f_omega_max =  f_corr_module ( j,k )
                location = j   
           end if
      end do

      omega_corr ( k ) = d_omega (k) * DBLE (location) *                  &   
                         thz_to_cm  /thertz/two/pi/atu

   end do


!
! output
!

   do j =1, n_step_use 
       do i = 1, n_atoms *3
           write (64,12,advance='NO') d_omega (i) * DBLE (j) *            &   
               thz_to_cm  /thertz/two/pi/atu
           write (64,12,advance='NO') f_corr_module ( j,i ) /             &   
                      e_mass**two * 27.2114**two /two**two /              &
                      boltzmann_k**two / two**two
       end do
       write (64,*)
   end do


   11  format(1x,i6,1x)
   12  format(1x,f25.15,1x)

   deallocate (window)
   deallocate (f_corr_module)
   deallocate (n_freq)
   deallocate (d_omega)

   close (64)

end subroutine corr_fourier
!**************************************************************************
subroutine corr_fit_fourier ( debug ) 
!**************************************************************************
!
!   Purpose: This subroutine performs Fourier transfrom of correlation function.  
! 
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug
  
!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n
  integer :: location, first, period
  integer :: n_freq

  double precision :: theta, f_omega_max
  double precision :: t, d_omega
  double precision, allocatable :: result (:,:)
  double precision, allocatable :: f_corr_module (:,:)
  double precision, allocatable :: ammode (:)
  double precision, allocatable :: taumode (:)

  complex ( kind = kind( 0.0d0 ) ) :: phase
  complex ( kind = kind( 0.0d0 ) ) :: f_corr

!*************************************************************************
!  Start of subroutine

   OPEN(unit=74, file='corr_fit_fourier.vaf')
   ! OPEN(unit=75, file='corr_fit_all.vaf')

   allocate (result (  n_step, n_atoms * 3 ) )
   allocate ( f_corr_module ( n_step, n_atoms * 3 ) ) 

   do i = 1, n_atoms * 3
      do k =1, n_step 
         t = d_t * k * atu
         result (k,i) = ammode (i) *                                      &
             COS( omega_corr_fit(i) / thz_to_cm * thertz * two * pi * t ) /  &
             EXP ( taumode (i) * t ) / 1000000.d0
      end do
   end do   

!
! fourier transform
!

   f_corr_module = zero 

   d_omega  = two * pi / d_t / dble (n_step ) / dble (5.0d0)
   n_freq  = n_step 

   do k =1,  n_atoms * 3

      write (6,*) k

      do j = 1, n_freq

          f_corr = CMPLX (zero, zero)

          do i = 1, n_step 

               theta = d_omega  * DBLE (j) * dble (i) * d_t
               phase = CMPLX ( COS( theta ), SIN ( theta ) )

               f_corr = f_corr +                                          &
                        CMPLX ( result (i,k), zero  ) * phase

          end do        

          f_corr_module ( j,k ) =                                         &
              ( ( DBLE ( f_corr ) )**2 + ( AIMAG ( f_corr ) )**2 ) /      &
              dble (n_step) 

      end do
   end do   


!
! output
!

   do j =1, n_step
       write(74,12,advance='NO') d_omega  * DBLE (j) *                 &   
                                 thz_to_cm  /thertz/two/pi/atu
       do i = 1, n_atoms *3
           write (74,12,advance='NO') f_corr_module ( j,i ) /             &   
                       e_mass**two * 27.2114**two /two**two /             &
                       boltzmann_k**two / two**two
       end do
       write(74,*)
   end do

   ! do k =1, n_step
   !   write (75,11,advance='NO') k   
   !   do i = 1, n_atoms *3
   !        write (75,12,advance='NO') result (k,i) /                       &   
   !                     e_mass * 27.2114 /two / boltzmann_k / two
   !   end do
   !   write (75,*)
   ! end do  


   11  format(1x,i5,1x)
   12  format(1x,f25.15,1x)

   deallocate (result)
   deallocate (f_corr_module)

   close (74)
   ! close (75)

end subroutine corr_fit_fourier
!**************************************************************************
subroutine maximum_entropy ( debug, velocity ) 
!**************************************************************************
!
!     Purpose:  maximum entropy method obtaining frequency via 
!               Linear Prediction method. 
!               It will also optionally perform a fitting of the maximum
!               entropy spectrum to a lorentzian function.
! 
!***************************************************************************
!  used modules
  
   use parameter
   use quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

  complex ( kind = kind( 0.0d0 ) ), intent (IN) :: velocity (n_step, n_atoms *3) 
 
!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n 
  integer :: n_freq_mem, location_mem

  double precision :: d_omega_mem, mem_max
  double precision :: theta
  double precision :: xms
  double precision :: wpr, wpi, wr, wi, sumr, sumi, wtemp
  double precision :: lorentzian_max, half_width, p_con
  double precision, allocatable :: d_entropy(:)
  double precision, allocatable :: evlmem (:, :)
  double precision, allocatable :: evlmem_mode (:)

  complex ( kind = kind( 0.0d0 ) ), allocatable :: data (:)
 
!*************************************************************************
!  Start of subroutine

   allocate( d_entropy ( pole ))  
   allocate( evlmem ( n_step, n_atoms * 3) )
   allocate( data ( n_step ) )
   allocate( evlmem_mode ( n_step ) ) 

   d_omega_mem = two * pi / d_t / dble (n_step_use )/ 10.0d0

   n_freq_mem = floor ( dble (n_step_use) / dble (2) )

   do j = 1, n_atoms * 3          ! for each mode

      data = velocity (:,j)

      call linear_response ( debug, data, pole, xms, d_entropy )

      do k = 1, n_freq_mem  

          theta = d_omega_mem * dble (k) * d_t       !  d_omega * dble (k) = freq 
          wpr = cos ( theta )
          wpi = sin ( theta )
          wr = one
          wi = zero
          sumr = one
          sumi = zero
          do i = 1, pole              !  pole == m (m as in linear prediction routine) 
              wtemp = wr
              wr = wr * wpr - wi * wpi
              wi = wi * wpr + wtemp * wpi

              sumr = sumr - d_entropy ( i ) *  ( wr )  !  a(k) = -d(k)
              sumi = sumi - d_entropy ( i ) *  ( wi )

          end do

          evlmem (k,j) = xms / ( sumr*sumr + sumi*sumi )

      end do
  end do

!
! calculation frequency from evlmem
!

 do j = 1, n_atoms * 3

     mem_max = zero
     
     do k = 1, n_freq_mem

          if (  evlmem (k,j) > mem_max ) then
               mem_max = evlmem (k,j)
               location_mem = k
          end if
     end do

     evlmem_mode =  evlmem (:,j)

    call lorentzian ( debug, evlmem_mode, location_mem, d_omega_mem,     &
                         lorentzian_max, half_width, p_con )

     omega_mem ( j ) = d_omega_mem * DBLE( location_mem )                 &
                         * thz_to_cm/thertz/two/pi/atu

     omega_lorentzian ( j ) = d_omega_mem * DBLE( lorentzian_max )          &
                         * thz_to_cm/thertz/two/pi/atu
  
  end do

end subroutine maximum_entropy 
!**************************************************************************
subroutine linear_response ( debug, data, m, xms, d ) 
!**************************************************************************
!
!     Purpose:  Linear Prediction method
!                            
!***************************************************************************
!  used modules
  
   use parameter
   use quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug 

  integer, intent (IN) :: m

  double precision, intent (inout) :: xms 
  double precision, intent (inout) :: d (m)

  complex ( kind = kind( 0.0d0 ) ), intent (IN) :: data (n_step)

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n 

  double precision :: denom, p, pneum 
  double precision, allocatable :: wkm(:) 

  complex ( kind = kind( 0.0d0 ) ), allocatable :: wk1(:)
  complex ( kind = kind( 0.0d0 ) ), allocatable :: wk2(:)

!*************************************************************************
!  Start of subroutine

  allocate( wkm ( m ) )     ! m = pole
  allocate ( wk1 (n_step) )
  allocate ( wk2 (n_step) )

  n = n_step_use 

  p = zero   
  do j=1, n
     p = p + DBLE ( CONJG ( data (j) ) * data (j) )
  end do

  xms = p / dble (n)
  wk1 (1) = data (1)
  wk2 (n-1) = data (n)
    
  do j=2, n -1
      wk1 (j) = data (j)
      wk2 (j-1) = data (j)
  end do

  do k =1, m
      pneum = zero
      denom = zero
      do j =1, n - k
          pneum = pneum + DBLE ( CONJG ( wk1 (j) ) * wk2 (j) )
          denom = denom + DBLE ( CONJG ( wk1 (j) ) * wk1 (j) ) + DBLE ( CONJG ( wk2 (j) ) * wk2 (j) )
      end do
      d ( k) = two * pneum / denom
      xms = xms * ( one - d (k) * d (k) )
 
      do i =1, k-1
          d (i) = wkm (i) - d(k) * wkm (k-i)
      end do

      if (k==m) return
  
      do i =1, k
         wkm (i) = d(i)
      end do

      do j =1, n - k - 1
           wk1 (j) = wk1 (j) - wkm (k) * wk2 (j)
           wk2 (j) = wk2 (j+1) - wkm (k) * wk1 (j+1)
      end do
  end do

  deallocate (wkm)
  deallocate (wk1)
  deallocate (wk2)

end subroutine linear_response 
!**************************************************************************
subroutine lorentzian ( debug, data, location, d_omega, max, width, p ) 
!**************************************************************************
!
!     Purpose:  Fit the maximum entropy strepctrum to a lorentzian function, 
!               output the maximum location and the half-height width.
!                
!***************************************************************************
!  used modules
  
   use parameter
   use quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

  integer, intent (IN) :: location 

  double precision, intent (IN) :: data ( n_step )  ! input data 
  double precision, intent (IN) :: d_omega
  double precision, intent (out) :: max 
  double precision, intent (OUT) :: width
  double precision, intent (OUT) :: p

!*************************************************************************
!  Local variables
  
  integer :: a, b, c, i, j, k, n, m 
  integer :: width0, interval
  integer :: xrange
  
  double precision :: dk_1, dk_2, x, tau, err, err1, fit, d_x, d_tau
  double precision :: unit_k, p0, para, max0, d_p
  
!*************************************************************************
!  Start of subroutine

  unit_k = one / ( d_omega *( thz_to_cm /thertz/two/pi/atu ) )

  dk_1 = two * unit_k                                               ! ~ 1 cm^-1 
  dk_2 = unit_k * 3.0d0                                             ! ~ 10 cm^-1

  width0 = unit_k * 30.0d0                                          ! ~ 30 cm^-1
  xrange = floor ( unit_k * 150.0d0 ) 

! Location is an integer, labels that the maximum value of evnmm_mode (k) is at k = location. 
! In the following, I would like to use "k" in the fitting.

  max = dble ( location )
  width = width0
  p = one

  a = 20
  b = 40
  c = 40

!  interval = floor (unit_k)

  interval = 1

  err1 = 10000000.0d0

  do n = 1, 21 
      d_x = dble (dk_1) / dble ( 1.5**(n-1) ) 
      d_tau = dble (dk_2) / dble ( 1.5**(n-1) ) 
      d_p = one /  dble ( 3**(n-1) ) 

      do i = 1, a 
      do j = 1, b 
      do m = 1, c      
 
         x = dble ( max ) + dble ( i - a/2 ) * d_x 
         tau = dble ( width ) +  dble ( j - b/2 )  * d_tau 
         para =  dble ( m - c/2 ) * d_p + p 

         err = zero
         do k = location - xrange, location + xrange, interval 
             fit = para * half * tau /                                    &
                   ( ( dble ( k ) - x )**2 + (half * tau)**2  ) 
             err = err + ( fit - data ( k ) )**2
         end do
   
         if ( err < err1 )  then
             err1 = err
             max0 = x
             width0 = tau             
             p0 = para 
         end if  
 
      end do
      end do 
      end do
 
      max = max0
      width = width0
      p = p0

  end do 

end subroutine lorentzian 
!**************************************************************************
subroutine gamma_matrix ( debug ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains the dynamics matrix from omega. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, u

  double precision, allocatable :: dynamics_matrix_q ( :,: ) 
  double precision, allocatable :: diagonal_matrix_q ( :,: )
  double precision, allocatable :: matrix_q ( :,: )
  double precision, allocatable :: omega_dynmat (:)

!*************************************************************************
!  Start of subroutine

  allocate( dynamics_matrix_q (n_atoms *3, n_atoms *3) )
  allocate( diagonal_matrix_q (n_atoms *3, n_atoms *3) )
  allocate( matrix_q (n_atoms *3, n_atoms *3)  )
  allocate ( omega_dynmat (n_atoms *3 ) )

  OPEN(unit=43, file='gamma_matrix.mat')
 
  write (6,*) "gamma_matrix ..."

  do i = 1, n_atoms * 3
       do j = 1, n_atoms * 3
             diagonal_matrix_q (i,j) = zero 
       end do
  end do

  omega_dynmat  =  omega_corr_fit / thz_to_cm   

  do i = 1, n_atoms * 3 
 
       diagonal_matrix_q (i,i ) = omega_dynmat (i)**2                     &   
          / ( ryd/amu/adu/adu ) *( thertz * two* pi )**2
 
  end do

  do i = 1, n_atoms * 3
      do j = 1, n_atoms * 3
       
          matrix_q ( i,j )  =  dot_product ( real_vector (i,:),           &
                              diagonal_matrix_q (:,j) )         
                
      end do
  end do
 
  do i = 1, n_atoms * 3
      do j = 1, n_atoms * 3
        
          dynamics_matrix_q ( i,j )  =  dot_product ( matrix_q (i,:),     &   
                               real_vector (j,:) )
            
      end do
  end do

  do k = 1, 3
  do u = 1, 3 
      do i = 1, n_atoms 
      do j = 1, n_atoms 

           dynamics_matrix_q ( 3*i -3 + k, 3*j-3 + u ) =                  &   
                dynamics_matrix_q ( 3*i -3 + k, 3*j-3 + u ) *             &
                 sqrt ( atom_mass (i) * atom_mass (j) )

      end do
      end do
  end do
  end do

  write (43,11)  n_atoms, n_atoms

  do i = 1, n_atoms
  do j = 1, n_atoms

      write (43,11)  i, j

      do k = 1, 3
    
           write (43,12)  dynamics_matrix_q ( 3*i-3+k, 3*j-3+1 ),         &   
                          dynamics_matrix_q ( 3*i-3+k, 3*j-3+2 ),         &
                          dynamics_matrix_q ( 3*i-3+k, 3*j-3+3 )  
      end do
  end do
  end do
  
  ! call gamma_force (debug, dynamics_matrix_q)

  close (43)

  11 format(1x,i5,1x,i5,1x)
  12 format(1x,f15.10,2x,f15.10,2x,f15.10,1x)

  deallocate (dynamics_matrix_q)
  deallocate (diagonal_matrix_q)
  deallocate (matrix_q)
  deallocate (omega_dynmat)

end subroutine gamma_matrix 
!**************************************************************************
subroutine gamma_force ( debug, dynamics_matrix_q ) 
!**************************************************************************
!
!     Purpose:  This subroutine obtains the dynamics matrix from omega. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug
  
  double precision, intent (IN) :: dynamics_matrix_q (n_atoms*3,n_atoms*3 )

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, u

  double precision :: diff, force0, forcetot
  double precision, allocatable :: displace ( :,: ) 
  double precision, allocatable :: force_h ( :,: )

!*************************************************************************
!  Start of subroutine

  OPEN(unit=44, file='gamma_force.out')

  allocate( displace (n_step, n_atoms *3) )
  allocate( force_h (n_step, n_atoms *3) )

  do k = 1, n_step_use
      do j =1, n_atoms

          displace ( k,j*3-2 ) =  displacement ( k,j,1 )
          displace ( k,j*3-1 ) =  displacement ( k,j,2 ) 
          displace ( k,j*3   ) =  displacement ( k,j,3 )   

      end do

      do i = 1, n_atoms * 3
          force_h (k,i ) = DOT_PRODUCT ( dynamics_matrix_q (i,:) ,        &   
                                         displace (k,:) )
      end do

  end do

    diff = zero
  force0 = zero
  forcetot=zero

  do k =1, n_step_use
       do i = 1, n_atoms
           diff = diff + (                                                &   
                         ( force_h (k,3*i-2) + md_force (k,i,1) )**two +  &   
                         ( force_h (k,3*i-1) + md_force (k,i,2) )**two +  &
                         ( force_h (k,3*i  ) + md_force (k,i,3) )**two )
           force0 = force0 + (                                            &   
                             force_h ( k,3*i-2 )**two +                   &
                             force_h ( k,3*i-2 )**two +                   &
                             force_h ( k,3*i-2 )**two ) 
           forcetot = forcetot + (                                        &   
                             md_force( k,i,1 )**two +                     &
                             md_force( k,i,2 )**two +                     &
                             md_force( k,i,3 )**two )
       end do
  end do

  write (44,*) "diff / force0 = "
  write (44,12) diff / force0, diff / forcetot   


  11 format(1x,i5,1x,i5,1x)
  12 format(1x,f15.10,1x,f20.10,1x)
  
  close (44)

  deallocate (displace)
  deallocate (force_h)  

end subroutine gamma_force 
!**************************************************************************
subroutine dynamics_matrix ( debug ) 
!**************************************************************************
!
!     Purpose:  This subroutine builds up the dynamics matrix from omega. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n, u

  double precision, allocatable :: omega_dynmat (:,:)
 
  complex ( kind = kind( 0.0d0 ) ), allocatable :: dynamic_matrix_q (:,:,:)
  complex ( kind = kind( 0.0d0 ) ), allocatable :: diagonal_matrix_q(:,:,:)
  complex ( kind = kind( 0.0d0 ) ), allocatable :: matrix_q ( :,:,: )
  complex ( kind = kind( 0.0d0 ) ), allocatable :: vector_q_conjg (:,:,:)

!*************************************************************************
!  Start of subroutine

  allocate( dynamic_matrix_q ( n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( diagonal_matrix_q ( n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( matrix_q ( n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( omega_dynmat (n_atom1 *3, super_size ) )
  allocate( vector_q_conjg (n_atom1 *3, n_atom1 *3, super_size ) )

  OPEN(unit=45, file='dynamical_matrix.mat')

  do i =1, n_atom1 *3 * super_size
       write ( 6,* ) i, omega_phonon (i)
  end do
 
  do j = 1, super_size  
      do i = 1, n_atom1 *3

           omega_dynmat (i,j) =  omega_phonon ( i + n_atom1 *3*(j-1) )   

           do k =1, n_atom1 *3
               diagonal_matrix_q (k,i,j) = CMPLX (zero, zero) 
           end do
           
           diagonal_matrix_q (i,i,j) =  CMPLX (                           &   
                 omega_dynmat (i,j) **two /                               &
                 ( ryd/amu/adu/adu ) * ( thertz * two* pi )**2, zero      &
                                              )

      end do
  end do

  do k = 1, super_size
      do i = 1, n_atom1 * 3
          do j = 1, n_atom1 * 3
       
               matrix_q ( i,j,k )  =  dot_product ( vector_q (i,:,k),    &   
                              diagonal_matrix_q (:,j,k) )         
                
          end do
      end do
  end do 

  do j = 1, super_size
       do i = 1, n_atom1 *3
            do k = 1, n_atom1 *3
                 vector_q_conjg (k,i,j) = CONJG ( vector_q (k,i,j) )       
            end do
       end do
  end do

  do k = 1, super_size
      do i = 1, n_atom1 * 3
          do j = 1, n_atom1 * 3
        
              dynamic_matrix_q ( i,j,k )  =                               &   
                  dot_product ( matrix_q (i,:,k), vector_q_conjg (j,:,k) )          
            
          end do
      end do
  end do

  ! do n = 1, super_size
  !     do i = 1, n_atom1
  !         do j = 1, n_atom1

  !             write (45,11) n, i, j

  !             do k = 1, 3
    
  !                   write (45,12)                                         &   
  !                        dynamic_matrix_q ( 3*i-3+k, 3*j-3+1,n )*e_mass,  &
  !                        dynamic_matrix_q ( 3*i-3+k, 3*j-3+2,n )*e_mass,  &
  !                        dynamic_matrix_q ( 3*i-3+k, 3*j-3+3,n )*e_mass 
  !             end do
  !         end do
  !     end do
  ! end do

 ! do n=1, super_size
 !     do i = 1, n_atom1 * 3
 !         write (45,*) n,i,omega_dynmat (i,n), omega_dynmat (i,n) * thz_to_cm 
 !         do j = 1, n_atom1 * 3
 !            write (45,"(2f20.10)") vector_q (j,i,n) 
 !         end do
 !     end do
 ! end do

  do n= 1, super_size 
      do k = 1, 3
         do u = 1, 3 
             do i = 1, n_atom1 
                 do j = 1, n_atom1 

                    dynamic_matrix_q ( 3*i -3 + k, 3*j-3 + u, n ) =       &   
                         dynamic_matrix_q ( 3*i -3 + k, 3*j-3 + u, n ) *  &
                         CMPLX ( sqrt( atom_mass(i) *atom_mass(j)), zero )

                 end do
             end do
         end do
      end do
  end do

!
! make the dyn file for pwscf
! 
  call write_dym ( debug,dynamic_matrix_q )

!
!  output dynamics matrix
!

  do n = 1, super_size
      do i = 1, n_atom1
          do j = 1, n_atom1

              write (45,11)  i, j

              do k = 1, 3
    
                    write (45,12)                                         &   
                              dynamic_matrix_q ( 3*i-3+k, 3*j-3+1,n ),    &
                              dynamic_matrix_q ( 3*i-3+k, 3*j-3+2,n ),    &
                              dynamic_matrix_q ( 3*i-3+k, 3*j-3+3,n )  
              end do
          end do
      end do
  end do

  close (45)

  11 format(1x,i5,1x,i5,1x,i5,1x)
  12 format(1x,f12.8,1x,f12.8,1x,f12.8,1x,f12.8,1x,f12.8,1x,f12.8,1x)

  deallocate (dynamic_matrix_q)
  deallocate (diagonal_matrix_q)
  deallocate (matrix_q)
  deallocate (omega_dynmat)
  deallocate (vector_q_conjg)

end subroutine dynamics_matrix 
!**************************************************************************
subroutine dynamics_matrix_md ( debug ) 
!**************************************************************************
!
!     Purpose:  This subroutine builds up the dynamics matrix from omega. 
!                            
!***************************************************************************
!  used modules
  
   use  parameter
   use  quantity

!************************************************************************

  implicit none

!*************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

!*************************************************************************
!  Local variables
  
  integer :: i, j, k, n, u

  double precision, allocatable :: omega_dynmat (:,:)
 
  complex ( kind = kind( 0.0d0 ) ), allocatable :: dynamic_matrix_q (:,:,:)
  complex ( kind = kind( 0.0d0 ) ), allocatable :: diagonal_matrix_q(:,:,:)
  complex ( kind = kind( 0.0d0 ) ), allocatable :: matrix_q ( :,:,: )
  complex ( kind = kind( 0.0d0 ) ), allocatable :: vector_q_conjg (:,:,:)

!*************************************************************************
!  Start of subroutine

  allocate( dynamic_matrix_q ( n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( diagonal_matrix_q ( n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( matrix_q ( n_atom1 *3, n_atom1 *3, super_size ) )
  allocate( omega_dynmat (n_atom1 *3, super_size ) )
  allocate( vector_q_conjg (n_atom1 *3, n_atom1 *3, super_size ) )

  write (6,*) "dynamical_matrix_md..."

  OPEN(unit=46, file='dynamical_matrix_md.mat')

  do j = 1, super_size  
      do i = 1, n_atom1 *3

           omega_dynmat (i,j) =  omega_corr_fit ( i + n_atom1 *3*(j-1) )/ &  
                                 thz_to_cm

           do k =1, n_atom1 *3
               diagonal_matrix_q (k,i,j) = CMPLX (zero, zero) 
           end do
           
           diagonal_matrix_q (i,i,j) =  CMPLX (                           &  
                 omega_dynmat (i,j) **two /                               &
                 ( ryd/amu/adu/adu ) * ( thertz * two* pi )**2, zero      &
                                              )

      end do
  end do

  do k = 1, super_size
      do i = 1, n_atom1 * 3
          do j = 1, n_atom1 * 3
       
               matrix_q ( i,j,k )  =  dot_product ( vector_q (i,:,k),    &   
                              diagonal_matrix_q (:,j,k) )         
                
          end do
      end do
  end do 

  do j = 1, super_size
       do i = 1, n_atom1 *3
            do k = 1, n_atom1 *3
                 vector_q_conjg (k,i,j) = CONJG ( vector_q (k,i,j) )       
            end do
       end do
  end do

  do k = 1, super_size
      do i = 1, n_atom1 * 3
          do j = 1, n_atom1 * 3
        
              dynamic_matrix_q ( i,j,k )  =                               &   
                  dot_product ( matrix_q (i,:,k), vector_q_conjg (j,:,k) )
            
          end do
      end do
  end do

  do n= 1, super_size 
      do k = 1, 3
         do u = 1, 3 
             do i = 1, n_atom1 
                 do j = 1, n_atom1 

                    dynamic_matrix_q ( 3*i -3 + k, 3*j-3 + u, n ) =       &  
                         dynamic_matrix_q ( 3*i -3 + k, 3*j-3 + u, n ) *  &
                         CMPLX ( sqrt( atom_mass(i) *atom_mass(j)), zero )

                 end do
             end do
         end do
      end do
  end do

!
! make the dyn file for pwscf
! 
  call write_dym ( debug, dynamic_matrix_q )

!
!  output dynamics matrix
!

  do n = 1, super_size
      do i = 1, n_atom1
          do j = 1, n_atom1

              write (46,11)  i, j

              do k = 1, 3
    
                    write (46,12)                                         &   
                              dynamic_matrix_q ( 3*i-3+k, 3*j-3+1,n ),    &
                              dynamic_matrix_q ( 3*i-3+k, 3*j-3+2,n ),    &
                              dynamic_matrix_q ( 3*i-3+k, 3*j-3+3,n )  
              end do
          end do
      end do
  end do

  close (46)

  11 format(1x,i5,1x,i5,1x,i5,1x)
  12 format(1x,f12.8,1x,f12.8,1x,f12.8,1x,f12.8,1x,f12.8,1x,f12.8,1x)

  deallocate (dynamic_matrix_q)
  deallocate (diagonal_matrix_q)
  deallocate (matrix_q)
  deallocate (omega_dynmat)
  deallocate (vector_q_conjg)

end subroutine dynamics_matrix_md 
!**************************************************************************
subroutine write_dym ( debug, dynamics_matrix_q )
!**************************************************************************
!    
!     Purpose:     This subroutine writes down the anharmonic / anharmonic 
!                  phonon information accrording to Quantum ESPRESSO ph.x 
!                  output file format, so that they can be read in by q2r.x.
!
!**************************************************************************
!  used modules

  use  quantity
  use  text

!**************************************************************************

  implicit none

!**************************************************************************
!  Shared variables

  logical, intent (IN) :: debug

  complex ( kind = kind( 0.0d0 ) ),intent(IN) ::                          &
           dynamics_matrix_q ( n_atom1 *3, n_atom1 *3, super_size )

!**************************************************************************
!  Local variables

  character ( len = 80 ) :: line
  character ( len = 30 ), dimension ( 10 ) :: words
  character ( len = 30 ), dimension ( 7 ), parameter ::                 &
       command = (/                             &
       'dynamical                    ',     & ! 1
       'dielectric                   ',     & ! 2
       'diagonalizing                ',     & ! 3
       'q                            ',     & ! 4
       'freq                         ',     & ! 5
       'effective                    ',     & ! 6
       'file                         '/)      ! 7
  character ( len = 50 ) :: filename
  character ( len = 80 ) :: line2
  character ( len = 3 ) :: tmp1

  integer :: i, j, k, n
  integer :: n_line  
  integer :: n_integers
  integer :: n_words
  integer :: n_reals
  integer :: n_stress
  integer :: status
  integer :: integer_numbers(10)
  integer :: i_dynamical, i_q, i_omega, i_effective

  double precision :: real_numbers(10)
  double precision :: real_1, real_2, real_3, image_1, image_2, image_3

!**************************************************************************
!  Start of subroutine

  if ( debug ) write(*,*) 'Entering read_input_mechanical()'

  write (6,*) "write dynamics matrix."

  n_line = 0
  i_q = 1
  i_omega = 0
  i_effective = 0

  rewind( unit = 21 )
 
  do                                                                       
     read(21, "(a80)", iostat = status ) line
     if ( status < 0 ) exit
        n_line = n_line + 1
        if ( line(1:1) == '#' ) cycle

     call split_line( line, n_words, words,                            &
         n_integers, integer_numbers,                                   &
         n_reals, real_numbers )

     if (words(1) == command(1)) then
          i_dynamical = i_dynamical + 1

          if ( words(3) == command(7) ) then
               i_dynamical = 0
               write (tmp1, "(i3)" ) i_q
               write (filename,*) "dynmatmd",adjustl(tmp1)
               OPEN (unit = 51, file=filename)
               i_omega = 0
               write (51,9)
               do i=1, 6 + n_species + n_atom1
                   read(21, "(a80)" ) line
                   if ( status < 0 ) exit
                   n_line = n_line + 1
                   write (51,"(a80)") line
               end do 

          else if ( i_dynamical == 1 ) then   
               write (51,*)
               write (51,8)
               write (51,*)
               read(21, "(a80)", iostat = status ) line
               if ( status < 0 ) exit
               n_line = n_line + 1
               read(21, "(a80)", iostat = status ) line
               if ( status < 0 ) exit
               n_line = n_line + 1
               call split_line( line, n_words, words,                     &
                         n_integers, integer_numbers,                     &
                         n_reals, real_numbers ) 
               write (51,10) real_numbers (1), real_numbers (2),          &
                             real_numbers (3) 
               write (51,*)

               do i = 1, n_atom1
               do j = 1, n_atom1
                   write (51,11)  i, j
                   do k = 1, 3    
                      write (51,12)                                     &
                         dynamics_matrix_q (3*i-3+k, 3*j-3+1, i_q ), &   
                         dynamics_matrix_q (3*i-3+k, 3*j-3+2, i_q ), &
                         dynamics_matrix_q (3*i-3+k, 3*j-3+3, i_q )  
                   end do
                end do
                end do

          else if ( i_dynamical /= 1 ) then
                read(21, "(a80)", iostat = status ) line
                if ( status < 0 ) exit
                n_line = n_line + 1
                read(21, "(a80)", iostat = status ) line
                if ( status < 0 ) exit
                n_line = n_line + 1

          end if

    else if( words(1) == command(2) )   then 
        write (51,*)
        write (51,7)
        do
            read(21, "(a80)", iostat = status ) line
            if ( status < 0 ) exit
            n_line = n_line + 1

            line2 = line

            if ( line(1:1) == '#' ) cycle
     
            call split_line( line, n_words, words,                    &
                 n_integers, integer_numbers,                         &
                 n_reals, real_numbers )
            
            if (words(1) == command(3)) exit

            if (words(1) == command(6)) then
                i_effective  = i_effective + 1
                if (i_effective ==1 ) then
                    write(51,15)
                else if  (i_effective ==2 ) then
                    write(51,16)
                end if
            else
                 write (51,"(a80)") line2
            end if
        end do

    else if( words(1) == command(4) )   then

        i_q = i_q + 1
 
        write (51,*)
        write (51,6)
        write (51,*) 
        call split_line( line, n_words, words,                     &
                         n_integers, integer_numbers,                     &
                         n_reals, real_numbers ) 
        write(51,10) real_numbers (1), real_numbers (2), real_numbers (3)
        write (51,*)
        write (51,*)                                                      &
  "*********************************************************************"

    else if( words(1) == command(5) )   then

         i_omega = i_omega + 1

         write (51,13) integer_numbers (1),                                  &   
                omega_corr_fit(i_omega + (i_q-2) * n_atom1 * 3) / thz_to_cm, &
                omega_corr_fit(i_omega + (i_q-2) * n_atom1 * 3)

         do i = 1, n_atom1

             read(21, "(a80)", iostat = status ) line
             if ( status < 0 ) exit
             n_line = n_line + 1
             if ( line(1:1) == '#' ) cycle
             call split_line( line, n_words, words,                       &
                   n_integers, integer_numbers,                           &
                   n_reals, real_numbers )

             real_1 = real_numbers (1)
             image_1 = real_numbers (2)

             read(21, "(a80)", iostat = status ) line
             if ( status < 0 ) exit
             n_line = n_line + 1
             if ( line(1:1) == '#' ) cycle
             call split_line( line, n_words, words,                       &
                  n_integers, integer_numbers,                            &
                  n_reals, real_numbers )

             real_2 = real_numbers (1)
             image_2 = real_numbers (2)

             read(21, "(a80)", iostat = status ) line
             if ( status < 0 ) exit
             n_line = n_line + 1
             if ( line(1:1) == '#' ) cycle
             call split_line( line, n_words, words,                       &
                   n_integers, integer_numbers,                           &
                   n_reals, real_numbers )

             real_3 = real_numbers (1)
             image_3 = real_numbers (2)

             write (51,14)  real_1, image_1, real_2, image_2,             &  
                            real_3, image_3

          end do
            
          if (i_omega == n_atom1 *3) then
             write(51,*)                                                  &
 "***********************************************************************"
             close (51)
          end if
      end if

  end do

 6  format(5x,"Diagonalizing",1x,"the",1x,"dynamical",1x,"matrix")
 7  format(5x,"Dielectric",1x,"Tensor:")
 8  format(5x,"Dynamical",1x,"Matrix",1x,"in",1x,"cartesian",1x," axes")
 9  format("Dynamical",1x,"matrix",1x,"file" )
 10 format(5x,"q",1x,"= (",3f14.9,2x,")")
 
 11 format(i5,i5)
 12 format(2f12.8,2x,2f12.8,2x,2f12.8)
 
 13 format(5x,"freq (",i2,") =",f15.6,1x,"[THz] =",f15.6,1x,"[cm-1]")
 14 format(1x,"(",f10.6,f10.6,f10.6,f10.6,f10.6,f10.6,1x,")")

 15 format (5x,"Effective",1x,"Charges",1x,"E-U:",1x,"Z_{alpha}{s,beta}")
 16 format (5x,"Effective",1x,"Charges",1x,"U-E:",1x,"Z_{s,alpha}{beta}")

end subroutine write_dym 
!**************************************************************************


end module main 
