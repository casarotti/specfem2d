
!========================================================================
!
!                   S P E C F E M 2 D  Version 7 . 0
!                   --------------------------------
!
! Copyright CNRS, INRIA and University of Pau, France,
! and Princeton University / California Institute of Technology, USA.
! Contributors: Dimitri Komatitsch, dimitri DOT komatitsch aT univ-pau DOT fr
!               Nicolas Le Goff, nicolas DOT legoff aT univ-pau DOT fr
!               Roland Martin, roland DOT martin aT univ-pau DOT fr
!               Christina Morency, cmorency aT princeton DOT edu
!               Pieyre Le Loher, pieyre DOT le-loher aT inria.fr
!
! This software is a computer program whose purpose is to solve
! the two-dimensional viscoelastic anisotropic or poroelastic wave equation
! using a spectral-element method (SEM).
!
! This software is governed by the CeCILL license under French law and
! abiding by the rules of distribution of free software. You can use,
! modify and/or redistribute the software under the terms of the CeCILL
! license as circulated by CEA, CNRS and INRIA at the following URL
! "http://www.cecill.info".
!
! As a counterpart to the access to the source code and rights to copy,
! modify and redistribute granted by the license, users are provided only
! with a limited warranty and the software's author, the holder of the
! economic rights, and the successive licensors have only limited
! liability.
!
! In this respect, the user's attention is drawn to the risks associated
! with loading, using, modifying and/or developing or reproducing the
! software by the user in light of its specific status of free software,
! that may mean that it is complicated to manipulate, and that also
! therefore means that it is reserved for developers and experienced
! professionals having in-depth computer knowledge. Users are therefore
! encouraged to load and test the software's suitability as regards their
! requirements in conditions enabling the security of their systems and/or
! data to be ensured and, more generally, to use and operate it in the
! same conditions as regards security.
!
! The full text of the license is available in file "LICENSE".
!
!========================================================================

  subroutine setup_sources_receivers(NSOURCES,initialfield,source_type,&
     coord,ibool,nglob,nspec,nelem_acoustic_surface,acoustic_surface,elastic,poroelastic, &
     x_source,z_source,ispec_selected_source,ispec_selected_rec, &
     is_proc_source,nb_proc_source,ipass,&
     sourcearray,Mxx,Mzz,Mxz,xix,xiz,gammax,gammaz,xigll,zigll,npgeo,&
     nproc,myrank,xi_source,gamma_source,coorg,knods,ngnod, &
     nrec,nrecloc,recloc,which_proc_receiver,st_xval,st_zval, &
     xi_receiver,gamma_receiver,station_name,network_name,x_final_receiver,z_final_receiver,iglob_source)

  implicit none

  include "constants.h"

  logical :: initialfield
  integer :: NSOURCES
  integer :: npgeo,ngnod,myrank,ipass,nproc
  integer :: nglob,nspec,nelem_acoustic_surface

  ! Gauss-Lobatto-Legendre points
  double precision, dimension(NGLLX) :: xigll
  double precision, dimension(NGLLZ) :: zigll

  ! for receivers
  integer  :: nrec,nrecloc
  integer, dimension(nrec) :: recloc, which_proc_receiver
  integer, dimension(nrec) :: ispec_selected_rec
  double precision, dimension(nrec) :: xi_receiver,gamma_receiver,st_xval,st_zval
  double precision, dimension(nrec) :: x_final_receiver, z_final_receiver

  ! timing information for the stations
  character(len=MAX_LENGTH_STATION_NAME), dimension(nrec) :: station_name
  character(len=MAX_LENGTH_NETWORK_NAME), dimension(nrec) :: network_name

  ! for sources
  integer, dimension(NSOURCES) :: source_type
  integer, dimension(NSOURCES) :: ispec_selected_source,is_proc_source,nb_proc_source,iglob_source
  real(kind=CUSTOM_REAL), dimension(NSOURCES,NDIM,NGLLX,NGLLZ) :: sourcearray
  double precision, dimension(NSOURCES) :: x_source,z_source,xi_source,gamma_source,Mxx,Mzz,Mxz

  logical, dimension(nspec) :: elastic,poroelastic
  integer, dimension(ngnod,nspec) :: knods
  integer, dimension(5,nelem_acoustic_surface) :: acoustic_surface
  integer, dimension(NGLLX,NGLLZ,nspec)  :: ibool
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLZ,nspec)  :: xix,xiz,gammax,gammaz
  double precision, dimension(NDIM,npgeo) :: coorg
  double precision, dimension(NDIM,nglob) :: coord

  integer  :: ixmin, ixmax, izmin, izmax

  ! Local variables
  integer i_source,ispec,ispec_acoustic_surface
#ifndef USE_MPI
  integer irec
#endif

  do i_source=1,NSOURCES

    if(source_type(i_source) == 1) then

      ! collocated force source
      call locate_source_force(ibool,coord,nspec,nglob,xigll,zigll,x_source(i_source),z_source(i_source), &
          ispec_selected_source(i_source),is_proc_source(i_source),nb_proc_source(i_source),&
          nproc,myrank,xi_source(i_source),gamma_source(i_source),coorg,knods,ngnod,npgeo,ipass,&
          iglob_source(i_source))

      ! check that acoustic source is not exactly on the free surface because pressure is zero there
      if(is_proc_source(i_source) == 1) then
        do ispec_acoustic_surface = 1,nelem_acoustic_surface
          ispec = acoustic_surface(1,ispec_acoustic_surface)
          ixmin = acoustic_surface(2,ispec_acoustic_surface)
          ixmax = acoustic_surface(3,ispec_acoustic_surface)
          izmin = acoustic_surface(4,ispec_acoustic_surface)
          izmax = acoustic_surface(5,ispec_acoustic_surface)
          if( .not. elastic(ispec) .and. .not. poroelastic(ispec) .and. &
            ispec == ispec_selected_source(i_source) ) then
            if ( (izmin==1 .and. izmax==1 .and. ixmin==1 .and. ixmax==NGLLX .and. &
                gamma_source(i_source) < -0.99d0) .or.&
                (izmin==NGLLZ .and. izmax==NGLLZ .and. ixmin==1 .and. ixmax==NGLLX .and. &
                gamma_source(i_source) > 0.99d0) .or.&
                (izmin==1 .and. izmax==NGLLZ .and. ixmin==1 .and. ixmax==1 .and. &
                xi_source(i_source) < -0.99d0) .or.&
                (izmin==1 .and. izmax==NGLLZ .and. ixmin==NGLLX .and. ixmax==NGLLX .and. &
                xi_source(i_source) > 0.99d0) .or.&
                (izmin==1 .and. izmax==1 .and. ixmin==1 .and. ixmax==1 .and. &
                gamma_source(i_source) < -0.99d0 .and. xi_source(i_source) < -0.99d0) .or.&
                (izmin==1 .and. izmax==1 .and. ixmin==NGLLX .and. ixmax==NGLLX .and. &
                gamma_source(i_source) < -0.99d0 .and. xi_source(i_source) > 0.99d0) .or.&
                (izmin==NGLLZ .and. izmax==NGLLZ .and. ixmin==1 .and. ixmax==1 .and. &
                gamma_source(i_source) > 0.99d0 .and. xi_source(i_source) < -0.99d0) .or.&
                (izmin==NGLLZ .and. izmax==NGLLZ .and. ixmin==NGLLX .and. ixmax==NGLLX .and. &
                gamma_source(i_source) > 0.99d0 .and. xi_source(i_source) > 0.99d0) ) then
              call exit_MPI('an acoustic source cannot be located exactly '// &
                            'on the free surface because pressure is zero there')
            endif
          endif
        enddo
      endif

    else if(source_type(i_source) == 2) then
      ! moment-tensor source
      call locate_source_moment_tensor(ibool,coord,nspec,nglob,xigll,zigll,x_source(i_source),z_source(i_source), &
             ispec_selected_source(i_source),is_proc_source(i_source),nb_proc_source(i_source),&
             nproc,myrank,xi_source(i_source),gamma_source(i_source),coorg,knods,ngnod,npgeo,ipass)

      ! compute source array for moment-tensor source
      call compute_arrays_source(ispec_selected_source(i_source),xi_source(i_source),gamma_source(i_source),&
             sourcearray(i_source,1,1,1), &
             Mxx(i_source),Mzz(i_source),Mxz(i_source),xix,xiz,gammax,gammaz,xigll,zigll,nspec)

    else if(.not.initialfield) then

      call exit_MPI('incorrect source type')

    endif

  enddo ! do i_source=1,NSOURCES

  ! locate receivers in the mesh
  call locate_receivers(ibool,coord,nspec,nglob,xigll,zigll, &
                      nrec,nrecloc,recloc,which_proc_receiver,nproc,myrank, &
                      st_xval,st_zval,ispec_selected_rec, &
                      xi_receiver,gamma_receiver,station_name,network_name, &
                      x_source(1),z_source(1), &
                      coorg,knods,ngnod,npgeo,ipass, &
                      x_final_receiver,z_final_receiver)

!! DK DK this below not supported in the case of MPI yet, we should do a MPI_GATHER() of the values
!! DK DK and use "if(myrank == which_proc_receiver(irec)) then" to display the right sources
!! DK DK and receivers carried by each mesh slice, and not fictitious values coming from other slices
#ifndef USE_MPI
  if (myrank == 0 .and. ipass == 1) then

     ! write actual source locations to file
     ! note that these may differ from input values, especially if source_surf = .true. in SOURCE
     ! note that the exact source locations are determined from (ispec,xi,gamma) values
     open(unit=14,file='DATA/for_information_SOURCE_actually_used',status='unknown')
     do i_source=1,NSOURCES
        write(14,*) x_source(i_source), z_source(i_source)
     enddo
     close(14)

     ! write out actual station locations (compare with STATIONS from meshfem2D)
     ! NOTE: this will be written out even if use_existing_STATIONS = .true.
     open(unit=15,file='DATA/for_information_STATIONS_actually_used',status='unknown')
     do irec = 1,nrec
        write(15,"('S',i4.4,'    AA ',f20.7,1x,f20.7,'       0.0         0.0')") &
             irec,x_final_receiver(irec),z_final_receiver(irec)
     enddo
     close(15)

  endif
#endif

  end subroutine setup_sources_receivers

