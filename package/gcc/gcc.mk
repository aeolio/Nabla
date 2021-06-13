################################################################################
#
# override package/gcc options
#
################################################################################

# prevent failure due to warnings during compilation of libcomp
# ../../../libgomp/target.c: In function ‘gomp_unmap_vars_internal’:
# ../../../libgomp/target.c:1474:9: error: unused variable ‘is_tgt_unmapped’ [-Werror=unused-variable]
#  1474 |    bool is_tgt_unmapped = gomp_remove_var (devicep, k);
#       |         ^~~~~~~~~~~~~~~

TARGET_CFLAGS += -Wno_error=unused-variable
