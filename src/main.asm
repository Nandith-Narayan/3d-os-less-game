[bits 32]
[ORG 0x01000000]
jmp main
%include "lib/keyboard.asm"
%include "images/temp.asm"
;%include "images/char.asm"
MAP_SIZE dd 5
GRID_SIZE dd 100
CAMERA_DISTANCE dd 280


player_x dd 180
player_y dd 280
old_player_x dd 0
old_player_y dd 0
temp_player_x dd 0
temp_player_y dd 0
player_angle dt 0.37079
temp_inc dt 0.0
turn_right_speed dt -0.05
turn_left_speed dt 0.05
move_speed dt 7.0

fov dt 1.0472 ;60 degrees in radian


; buffer for double buffering the screen
screen_buffer TIMES 64000 db 0
game_state db 0 ; 0 = main menu, 1 = game run state, 2 = loser


map db 1,1,1,1,1
    db 1,0,0,0,1
   db 0,0,0,0,1
    db 1,0,0,0,1
    db 0,0,0,1,1

ray_angle dt 0.0
ray_angle_incriment dt 0.00327249235
frame_count db 0

main:
    
    mov eax, 0
    mov ebx, 0
    mov edx, 0
    mov ecx, 0
    call move
    call cast_rays
    call write_buffer_to_screen
    call clear_buffer
    mov al, [frame_count]
    inc al
    mov [frame_count],al
jmp main
CONST_2 dt 2.0
ray_count dd 0

move:
    mov eax, [player_x]
    mov [old_player_x], eax
    
    mov eax, [player_y]
    mov [old_player_y], eax


    finit 
    fldz
    fstp tword[temp_inc]


    ; check if A is pressed
    mov eax,0
    call handle_buffer
    mov eax, keycode_a
    call is_pressed
    test eax, eax
    jz .skip_turn_left
        ; turn left
        finit 
        fld tword[turn_left_speed]
        fstp tword[temp_inc]
    .skip_turn_left:
    ; check if D is pressed
    mov eax,0
    call handle_buffer
    mov eax, keycode_d
    call is_pressed
    test eax, eax
    jz .skip_turn_right
        ;turn right
        finit 
        fld tword[turn_right_speed]
        fstp tword[temp_inc]
        
    .skip_turn_right:
    
    ; check if W is pressed
    mov eax,0
    call handle_buffer
    mov eax, keycode_w
    call is_pressed
    test eax, eax
    jz .skip_move_forward
        ;move forward
        finit 
        fld tword[player_angle]
        fcos
        fld tword[move_speed]
        fmul
        fild dword[player_x]
        fadd
        fist dword[player_x]
        finit 
        fld tword[player_angle]
        fsin
        fld tword[move_speed]
        fmul
        fchs
        fild dword[player_y]
        fadd
        fist dword[player_y]
        
    .skip_move_forward:
    
    ; check if S is pressed
    mov eax,0
    call handle_buffer
    mov eax, keycode_s
    call is_pressed
    test eax, eax
    jz .skip_move_backward
        ;move backwards
        finit 
        fld tword[player_angle]
        fcos
        fld tword[move_speed]
        fmul
        fchs
        fild dword[player_x]
        fadd
        fist dword[player_x]
        finit 
        fld tword[player_angle]
        fsin
        fld tword[move_speed]
        fmul
        fild dword[player_y]
        fadd
        fist dword[player_y]
        
    .skip_move_backward:
    
    
    mov eax, [player_x]
    mov edx, 0
    mov ebx, [GRID_SIZE]
    div ebx
    mov [temp_player_x], eax
    
    mov eax, [player_y]
    mov edx, 0
    mov ebx, [GRID_SIZE]
    div ebx
    mov [temp_player_y], eax
    
    mov eax, [temp_player_y]
    mov ebx, [MAP_SIZE]
    mov edx, 0
    mul ebx
    add eax, [temp_player_x]
    add eax, map
    mov bl, [eax]
    cmp bl, 0
    je .all_good
        mov eax, [old_player_x]
        mov [player_x], eax
        
        mov eax, [old_player_y]
        mov [player_y], eax
            
    .all_good:
    ret
    



distance dd 0
temp_val dd 0
texture_offset dd 0
texture_offset_y dd 0

cast_rays:
    finit
    fld tword[player_angle]
    fld tword[temp_inc]
    fadd
    fstp tword[player_angle]
    ; ray_angle = player_angle + fov/2
    finit
    fld tWord[fov]  
    fld tWORD[CONST_2]
    fdiv   
    fld tWORD[player_angle] 
    fadd  
    fstp tWORD[ray_angle]
    
    mov ecx, 0
    
ray_loop:
    mov [ray_count], ecx
    finit
    call cast_ray_x
    
    ;check if ray hit anything
    mov eax, 10000000
    mov [distance], eax
    mov al, [wall_hit]
    cmp al, 0
    je .no_hit_x
        
        ; ray hit something so calculate square of distance
        ; distance = (player_x-intersection_x)^2 + (player_y-intersection_y)^2
        ;xchg bx,bx
        mov eax, [player_x]
        mov ebx, [intersection_x]
        sub eax, ebx
        mov edx, 0
        mov ebx, 0
        imul eax
        mov [temp_val], eax
        
        mov eax, [player_y]
        mov ebx, [intersection_y]
        sub eax, ebx
        mov edx, 0
        mov ebx, 0

        imul eax
        mov ebx, [temp_val]
        add eax, ebx
        mov [distance], eax
        
        
    .no_hit_x:
    finit
    mov eax, 0
    mov ebx, 0
    mov edx, 0
    call cast_ray_y
    
    ;check if ray hit anything
    mov al, [wall_hit_y]
    cmp al, 0
    je .no_hit_y1
        ; ray hit something so calculate square of distance
        ; distance = (player_x-intersection_x)^2 + (player_y-intersection_y)^2
        ;xchg bx,bx
        mov eax, [player_x]
        mov ebx, [intersection_x]
        sub eax, ebx
        mov edx, 0
        mov ebx, 0
        imul eax
        mov [temp_val], eax
        
        mov eax, [player_y]
        mov ebx, [intersection_y]
        sub eax, ebx
        mov edx, 0
        mov ebx, 0

        imul eax
        mov ebx, [temp_val]
        add eax, ebx
        cmp eax, [distance]
        jge .no_hit_y1
            
            mov [distance], eax
            mov al, [wall_hit_y]
            mov [wall_hit], al
            mov eax, [texture_offset_y]
            mov [texture_offset], eax
            mov al, 0
            mov [ray_hit_was_x], al
    .no_hit_y1:
    
    call draw_slice
    ; decriment ray_angle
    finit
    
    fld tWORD[ray_angle]
    fld tWORD[ray_angle_incriment]
    fsub
    fstp tWORD[ray_angle]
    
    mov ecx,[ray_count]
    ; Debugging strobe
     
    ;mov eax, screen_buffer
    ;add eax, ecx
    ;mov dl, [frame_count]
    ;mov byte[eax], dl
    
 
    
    
    
    inc ecx   
    cmp ecx, 320
    jl ray_loop

    ret

wall_height dd 0
top_of_wall_pixel dd 0
image_slice TIMES 100 db 0
scaled_image_slice TIMES 200 db 0
vertical_offset dd 0;signed offset used for scaling slice
temp_pixel dd 0
texture dd 0
draw_slice:
    
    ; if ray didn't hit then skip drawing
    mov eax, [distance]
    cmp eax, 10000000
    jne .calculate_wall_height
        ret
    
    
    
    .calculate_wall_height:
    
    finit 
    fild dword[distance]
    fsqrt
    fist dword[distance]
    ; correct for distortion actual Distance = Distance * cos(player_angle-ray_angle)
    finit
    fld TWORD[player_angle]
    fld TWORD[ray_angle]
    fsub
    fcos
    fild Dword[distance]
    fmul
    fist Dword[distance]
    
    ; wall_height = CAMERA_DISTANCE * GRID_SIZE/(Distance of ray)
    finit
    fild dword[GRID_SIZE]
    fild dword[distance]
    fdiv
    fild dword[CAMERA_DISTANCE]
    fmul
    fist dword[wall_height]
    
    mov eax, [wall_height]
    cmp eax, 199
    jle .skip_clamp
        ;mov eax, 199
        ;mov [wall_height], eax  
    .skip_clamp:
    
    ;load texture
    mov ecx, 0
    .load_texture_loop:
     
        mov edx, 0
        mov eax, ecx
        mov ebx, 100
        mul ebx
        add eax, [texture_offset]
        mov ebx, wall_2_data
        mov dl, [ray_hit_was_x]
        cmp dl, 1
        je .ray_that_hit_was_x
            mov ebx, wall_1_data
        .ray_that_hit_was_x:
        add eax, ebx
        mov bl, [eax]
        
        mov eax, ecx
        add eax, image_slice
        mov [eax], bl
    inc ecx
    cmp ecx, 100
    jl .load_texture_loop
    ;scale texture
    ;reset slice buffer
    mov ecx, 0
    .reset_scaled_image_slice_loop:
      
        mov eax, ecx
        add eax, scaled_image_slice
        mov byte[eax], 0
    inc ecx
    cmp ecx, 200
    jl .reset_scaled_image_slice_loop
    
    ;offset = (wall_height-200)/2
    mov eax, [wall_height]
    mov ebx, 200
    sub eax, ebx
    mov edx, 0
    mov ebx, 2
    sar eax, 1
    mov [vertical_offset], eax
 
    
    
    mov ecx, 0
    .scale_texture_loop:
    mov eax, [vertical_offset]
    add eax, ecx
    cmp eax, 0
    jl .skip_this_pixel
    mov ebx, [wall_height]
    cmp eax, ebx
    jge .skip_this_pixel2
        
        mov [temp_pixel], eax
        finit
        fild dword[temp_pixel]
        fild dword[wall_height]
        fdiv
        fild dword[GRID_SIZE]
        fmul
        fist Dword[temp_pixel]
        mov eax, [temp_pixel]
        add eax, image_slice
        mov bl, [eax]
        mov eax, ecx
        add eax, scaled_image_slice
        mov [eax], bl
    .skip_this_pixel:
    inc ecx
    cmp ecx, 200
    jb .scale_texture_loop
    .skip_this_pixel2:
    ;top_of_wall_pixel = (screen_height - wall_height)/2
    ;mov eax, 200
    ;mov ebx, [wall_height]
    ;sub eax, ebx
    ;shr eax, 1
    ;mov [top_of_wall_pixel], eax
    ;mov ecx, [wall_height]
    mov ecx, 0
    ;dec ecx
    
    .draw_loop:
    mov edx, 0
    mov eax, 320
    ;mov ebx, [top_of_wall_pixel]
    mov ebx, ecx
    mul ebx
    add eax, [ray_count]
    add eax, screen_buffer
    mov ebx, scaled_image_slice
    add ebx, ecx
    mov dl, [ebx]
    ;mov bl, [wall_hit]
    cmp dl, 0
    je .skip_drawing_this_pixel
        mov byte[eax], dl
                

    .skip_drawing_this_pixel:
    inc ecx
    cmp ecx, 200
    
    jl .draw_loop
    ret

delta_x dd 0
delta_y dd 0

intersection_x dd 0
intersection_y dd 0
temp_var dd 0
grid_x dd 0
grid_y dd 0

wall_hit db 0
wall_hit_y db 0
temp_angle dd 0
ray_hit_was_x db 0
cast_ray_x:
    
    ; if ray is travelling downwards then delta_y = +GRID_SIZE
    ; else delta_y = -GRID_SIZE
    finit
    mov eax, 10000
    mov [temp_angle], eax
    fld tword[ray_angle]
    fsin
    fild Dword[temp_angle]
    fmul
    fist Dword[temp_angle]
    mov eax, [temp_angle]
    cmp eax, 0
    jg .ray_is_upwards
    mov eax, [GRID_SIZE]
    
    mov [delta_y], eax
    mov edx, 0
    ; intersection_y = ((player_y/GRID_SIZE)+1)*GRID_SIZE
    mov eax, [player_y]
    mov ebx, [GRID_SIZE]
    div ebx
    mov ebx, [GRID_SIZE]
    inc eax
    mov edx, 0
    mul ebx
    
    mov [intersection_y], eax
    
    ; delta_x = GRID_SIZE/tan(ray_angle)
    
    finit
    fld tword[ray_angle]
    fsincos
    fdiv
    fild Dword[GRID_SIZE]
    fdivr
    fist Dword[delta_x]
    mov eax, [delta_x]
    neg eax ; negate delta_x when ray is facing down
    mov [delta_x], eax
    
   
    jmp .ray_is_downwards
.ray_is_upwards:

    mov eax, [GRID_SIZE]
    neg eax
    mov [delta_y], eax
    ; intersection_y = (player_y/GRID_SIZE)*GRID_SIZE -1
    mov edx, 0
    mov eax, [player_y]
    mov ebx, [GRID_SIZE]
    div ebx
    mov ebx, [GRID_SIZE]
    mov edx, 0
    mul ebx
    dec eax
    mov [intersection_y], eax
    
    ; delta_x = GRID_SIZE/tan(ray_angle)
    
    finit
    fld tword[ray_angle]
    fsincos
    fdiv
    fild Dword[GRID_SIZE]
    fdivr
    fist Dword[delta_x]
    
.ray_is_downwards:
    
    ;intersection_x = Player_x + (player_y-intersection_y)*tan(ray_angle)
    
    finit
    mov eax, [player_y]
    mov ebx, [intersection_y]
    sub eax, ebx
    mov [temp_var], eax
    fld tword[ray_angle]
    fsincos
    fdiv
    fild dword[temp_var]
    fdivr
    fist dword[temp_var]
    mov eax, dword[temp_var]
    add eax, [player_x]
    mov [intersection_x], eax
    
    .interection_check:
    ; check for wall at interection point with grid
    ; grid_y = intersection_y / GRID_SIZE
    mov edx, 0
    mov eax, [intersection_y]
    mov ebx, [GRID_SIZE]
    div ebx
    mov [grid_y], eax
    
    ; grid_x = intersection_x / GRID_SIZE
    mov edx, 0
    mov eax, [intersection_x]
    mov ebx, [GRID_SIZE]
    div ebx
    mov [grid_x], eax
    
    ; if grid_x or grid_y is invalid then consider ray to have not hit anything
    mov eax, [grid_x]
    cmp eax, 0
    jl .out_of_bounds
    mov eax, [grid_x]
    cmp eax, [MAP_SIZE]
    jge .out_of_bounds
    mov eax, [grid_y]
    cmp eax, 0
    jl .out_of_bounds
    mov eax, [grid_y]
    cmp eax, [MAP_SIZE]
    jge .out_of_bounds
    jmp .check_for_wall
    .out_of_bounds:
        mov al, 0
        mov [wall_hit], al
        ret
    .check_for_wall:
    ;check if object at grid_x,grid_y is a wall or not
    mov edx, 0
    mov eax, [grid_y]
    mov ebx, [MAP_SIZE]
    mul ebx
    add eax, [grid_x]
    add eax, map
    mov al, [eax]
    cmp al, 0
    je .no_wall_hit
        mov [wall_hit], al
        mov edx, 0
        mov eax, [intersection_x]
        mov ebx, 100
        div ebx
        mov [texture_offset], edx
        mov al, 1
        mov [ray_hit_was_x], al
        ret
    .no_wall_hit:
    ; add delta_x and delta_y to intersection point
    ; and repeat calculation
    
    mov eax, [intersection_x]
    add eax, [delta_x]
    mov [intersection_x], eax
    
    mov eax, [intersection_y]
    add eax, [delta_y]
    mov [intersection_y], eax
    
    jmp .interection_check
    
    ret
cast_ray_y:
    
    ; if ray is travelling right then delta_x = +GRID_SIZE
    ; else delta_x = -GRID_SIZE
    finit
    
    mov eax, 10000
    mov [temp_angle], eax
    fld tword[ray_angle]
    fcos
    fild Dword[temp_angle]
    fmul
    fist Dword[temp_angle]
    mov eax, [temp_angle]
    cmp eax, 0
    jle .ray_is_left;
    mov eax, [GRID_SIZE]
    mov [delta_x], eax
    mov edx, 0
    ; intersection_x = ((player_x/GRID_SIZE)+1)*GRID_SIZE
    mov eax, [player_x]
    mov ebx, [GRID_SIZE]
    div ebx
    mov ebx, [GRID_SIZE]
    inc eax
    mov edx, 0
    mul ebx
    mov [intersection_x], eax
    ; delta_y = delta_x*tan(ray_angle)
    
    finit
    fld tword[ray_angle]
    fsincos
    fdiv
    fild Dword[delta_x]
    fmul
    fist Dword[delta_y]
    mov eax, [delta_y]
    neg eax
    mov [delta_y], eax

    jmp .ray_is_right
.ray_is_left:
    mov eax, [GRID_SIZE]
    neg eax
    mov [delta_x], eax
    ; intersection_x = (player_x/GRID_SIZE)*GRID_SIZE -1
    mov edx, 0
    mov eax, [player_x]
    mov ebx, [GRID_SIZE]
    div ebx
    mov ebx, [GRID_SIZE]
    mov edx, 0
    mul ebx
    dec eax
    mov [intersection_x], eax
    
    ; delta_y = delta_x*tan(ray_angle)
    
    finit
    fld tword[ray_angle]
    fsincos
    fdiv
    fild Dword[delta_x]
    fmul
    fist Dword[delta_y]
    mov eax, [delta_y]
    neg eax
    mov [delta_y], eax
    
.ray_is_right:

    
    
    ;intersection_y = Player_y + (player_x-intersection_x)*tan(ray_angle)
    
    finit
    mov eax, [player_x]
    mov ebx, [intersection_x]
    sub eax, ebx
    
    mov [temp_var], eax
    fld tword[ray_angle]
    fsincos
    fdiv
    fild dword[temp_var]
    fmul
    fist dword[temp_var]
    mov eax, [temp_var]
    mov ebx, [player_y]
    add eax, ebx
    mov [intersection_y], eax
    
    .interection_check_y:
    ; check for wall at interection point with grid
    ; grid_y = intersection_y / GRID_SIZE
    mov edx, 0
    mov eax, [intersection_y]
    mov ebx, [GRID_SIZE]
    div ebx
    mov [grid_y], eax
    
    ; grid_x = intersection_x / GRID_SIZE
    
    mov edx, 0
    mov eax, [intersection_x]
    mov ebx, [GRID_SIZE]
    div ebx
    mov [grid_x], eax
    
    ; if grid_x or grid_y is invalid then consider ray to have not hit anything
    mov eax, [grid_x]
    cmp eax, 0
    jl .out_of_bounds_y
    
    mov eax, [grid_x]
    cmp eax, [MAP_SIZE]
    jae .out_of_bounds_y

    mov eax, [grid_y]
    cmp eax, 0
    jl .out_of_bounds_y
    mov eax, [grid_y]
    cmp eax, [MAP_SIZE]
    jge .out_of_bounds_y
    jmp .check_for_wall_y
    
    .out_of_bounds_y:
        mov al, 0
        mov [wall_hit_y], al
        
        ret
    .check_for_wall_y:
    
    ;check if object at grid_x,grid_y is a wall or not
    mov edx, 0
    mov eax, [grid_y]
    mov ebx, [MAP_SIZE]
    mul ebx
    add eax, [grid_x]
    add eax, map
    mov al, [eax]
    cmp al, 0
    
    je .no_wall_hit_y
        mov [wall_hit_y], al
        mov edx, 0
        mov eax, [intersection_y]
        mov ebx, 100
        div ebx
        mov [texture_offset_y], edx
        ret
    .no_wall_hit_y:
    
    ; add delta_x and delta_y to intersection point
    ; and repeat calculation
    
    mov eax, [intersection_x]
    add eax, [delta_x]
    mov [intersection_x], eax
    
    mov eax, [intersection_y]
    add eax, [delta_y]
    mov [intersection_y], eax
    
    jmp .interection_check_y
    
    ret
debug:
 mov eax, screen_buffer
        mov ebx, 1000
        add eax, ebx
        mov dl, 174
        mov byte[eax], dl
    ret
write_buffer_to_screen:


    mov esi, screen_buffer
    mov edi, 0xA0000
    mov ecx, 64000
    rep movsb


    ret
clear_buffer:

    mov ecx, 32000
    .draw_roof_loop:
    mov eax, screen_buffer
    add eax, ecx
    dec eax
    mov byte[eax], 11
    loop .draw_roof_loop
    
    mov ecx, 32000
    .draw_floor_loop:
    mov eax, screen_buffer
    mov ebx, 32000
    add eax, ebx
    add eax, ecx
    dec eax
    mov byte[eax], 6
    loop .draw_floor_loop
    
    ret

