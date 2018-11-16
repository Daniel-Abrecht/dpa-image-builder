#define _DEFAULT_SOURCE
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdbool.h>
#include <unistd.h>
#include <com_err.h>
#include <ext2fs/ext2fs.h>
#include <libtar.h>

enum entry_type {
  ET_UNKNOWN,
  ET_REGULAR,
  ET_HARDLINK,
  ET_SYMLINK,
  ET_CHARACTER_DEVICE,
  ET_BLOCK_DEVICE,
  ET_FIFO,
  ET_DIRECTORY
};

static TAR* tar;
static ext2_filsys global_fs;
static char buffer[T_BLOCKSIZE];

enum entry_type helper_tar_get_type(TAR* tar){
  if(TH_ISREG(tar)){
    return ET_REGULAR;
  }else if(TH_ISLNK(tar)){
    return ET_HARDLINK;
  }else if(TH_ISSYM(tar)){
    return ET_SYMLINK;
  }else if(TH_ISCHR(tar)){
    return ET_CHARACTER_DEVICE;
  }else if(TH_ISBLK(tar)){
    return ET_BLOCK_DEVICE;
  }else if(TH_ISFIFO(tar)){
    return ET_FIFO;
  }else if(TH_ISDIR(tar)){
    return ET_DIRECTORY;
  }
  return ET_UNKNOWN;
}

void myperror(const char* what){
  com_err(what, errno, 0);
}

// Note, acts as if cwd == / and no symlinks, removes . and ..
// Returns \0 separeted list, list is terminated with an additional \0
char* mkdirlist(const char* path, bool ab){
  size_t listsize = strlen(path) + 2 + ab;
  char* list = malloc(listsize);
  if(!list){
    myperror("malloc failed");
    return 0;
  }
  char*const result = list;
  if(ab)
    *(list++) = '/';
  size_t cmps = 0;
  bool lsl = true;
  for(const char* it=path; *it; it++){
    if(*it == '.'){
      if(it[1] == '/'){
        continue;
      }else if(it[1] == '.' && it[2] == '/'){
        it++;
        if(cmps == 0) // ../ at /, assuming /../ = /
          continue;
        cmps--;
        list -= 1;
        while(list[-1])
          list -= 1;
      }
    }else if(*it == '/'){
      if(lsl) continue;
      lsl = true;
      cmps += 1;
      *list++ = ab ? '/' : 0;
      continue;
    }
    *list++ = *it;
    lsl = false;
  }
  if(!lsl || list == result)
    *list++ = 0;
  *list++ = 0;
  return result;
}

int helper_ext_stat(ext2_ino_t inode, const struct stat* statbuf){
  errcode_t err = 0;
  struct ext2_inode_large full_inode;
  memset(&full_inode, 0, sizeof(full_inode));
  err = ext2fs_read_inode_full(global_fs, inode, (struct ext2_inode*)&full_inode, sizeof(full_inode));
  if(err){
    errno = err;
    myperror("ext2fs_read_inode_full failed");
    return -1;
  }
  if(statbuf){
    if((statbuf->st_mode & S_IFMT) && (full_inode.i_mode & S_IFMT) != (statbuf->st_mode & S_IFMT)){
      fprintf(stderr, "Inode type and type specified in mode mismatch");
      return -1;
    }
    full_inode.i_uid = statbuf->st_uid;
    full_inode.i_gid = statbuf->st_gid;
    full_inode.i_mode = (full_inode.i_mode & S_IFMT) | (statbuf->st_mode & ~S_IFMT);
    if(statbuf->st_atime)
      full_inode.i_atime = statbuf->st_atime;
    if(statbuf->st_ctime)
      full_inode.i_ctime = statbuf->st_ctime;
    if(statbuf->st_mtime)
      full_inode.i_mtime = statbuf->st_mtime;
  }else{
    full_inode.i_mtime = time(0);
  }
  // Ignoring i_dtime, not in stat struct
  err = ext2fs_write_inode_full(global_fs, inode, (struct ext2_inode*)&full_inode, sizeof(full_inode));
  if(err){
    errno = err;
    myperror("ext2fs_write_inode_full failed");
    return -1;
  }
  return 0;
}

int helper_ext_update(ext2_ino_t inode){
  return helper_ext_stat(inode, 0);
}

int helper_ext_mkdir_follow(ext2_ino_t inode, char* name, ext2_ino_t* result){
  errcode_t err = 0;
  ext2_ino_t next;
  // Try to get inode, follow links
  err = ext2fs_namei_follow(global_fs, EXT2_ROOT_INO, inode, name, &next);
  if(err && err != EXT2_ET_FILE_NOT_FOUND){
    errno = err;
    myperror("ext2fs_namei_follow failed");
    return -1;
  }else if(err){
    // Get inode info of parent directory
    struct ext2_inode_large parent_inode;
    memset(&parent_inode, 0, sizeof(parent_inode));
    err = ext2fs_read_inode_full(global_fs, inode, (struct ext2_inode*)&parent_inode, sizeof(parent_inode));
    if(!(parent_inode.i_mode & LINUX_S_IFDIR)){
      errno = ENOTDIR;
      myperror("wrong inode type");
      return -1;
    }
    // create missing directories
    err = ext2fs_mkdir(global_fs, inode, 0, name);
    if(err == EXT2_ET_DIR_NO_SPACE){
      err = ext2fs_expand_dir(global_fs, inode);
      if(!err)
        err = ext2fs_mkdir(global_fs, inode, 0, name);
    }
    if(err){
      errno = err;
      myperror("ext2fs_mkdir failed");
      return -1;
    }
/*    if(helper_ext_update(inode)){
      perror("helper_ext_update failed");
      return -1;
    }*/
    // Get inode of new directory
    err = ext2fs_namei_follow(global_fs, EXT2_ROOT_INO, inode, name, &next);
    if(err){
      errno = err;
      myperror("ext2fs_namei_follow failed");
      return -1;
    }
    struct stat statbuf = {
      .st_uid = parent_inode.i_uid,
      .st_gid = parent_inode.i_uid,
      .st_mode = parent_inode.i_mode,
      .st_atime = parent_inode.i_atime,
      .st_mtime = parent_inode.i_mtime,
      .st_ctime = parent_inode.i_ctime
    };
    if(helper_ext_stat(next, &statbuf)){
      myperror("helper_ext_stat failed");
      return -1;
    }
  }else{
    // Read inode
    struct ext2_inode_large child_inode;
    memset(&child_inode, 0, sizeof(child_inode));
    err = ext2fs_read_inode_full(global_fs, next, (struct ext2_inode*)&child_inode, sizeof(child_inode));
    if(err){
      errno = err;
      myperror("ext2fs_read_inode_full failed");
      return -1;
    }
    // Check that it really is a directory
    if(!(child_inode.i_mode & LINUX_S_IFDIR)){
      errno = -ENOTDIR;
      myperror("wrong inode type");
      return -1;
    }
  }
  *result = next;
  return 0;
}

int helper_ext_file_type(mode_t mode){
  if(LINUX_S_ISREG(mode))
    return EXT2_FT_REG_FILE;
  if(LINUX_S_ISDIR(mode))
    return EXT2_FT_DIR;
  if(LINUX_S_ISCHR(mode))
    return EXT2_FT_CHRDEV;
  if(LINUX_S_ISBLK(mode))
    return EXT2_FT_BLKDEV;
  if(LINUX_S_ISLNK(mode))
    return EXT2_FT_SYMLINK;
  if(LINUX_S_ISFIFO(mode))
    return EXT2_FT_FIFO;
  if(LINUX_S_ISSOCK(mode))
    return EXT2_FT_SOCK;
  return 0;
}

int helper_ext_create(ext2_ino_t* result){
  errcode_t err = 0;
  // Turn the file path into a list
  ext2_ino_t inode = EXT2_ROOT_INO;
  char* list = mkdirlist(tar->th_buf.name, false);
  if(!list){
    myperror("mkdirlist failed");
    return -1;
  }
  if(!*list){ // Root directory specified
    goto end;
  }
  // Create or follow each directory component and get inode of directory for new file
  char* component;
  char* it = list;
  do {
    component = it;
    while(*(it++));
    if(!*it) break;
    if(helper_ext_mkdir_follow(inode, component, &inode)){
      myperror("helper_ext_mkdir_follow failed");
      goto error;
    }
  } while(true);
  // Get type of file to create
  enum entry_type type = helper_tar_get_type(tar);
  struct stat statbuf = {
    .st_uid  = th_get_uid(tar),
    .st_gid  = th_get_gid(tar),
    .st_mode = th_get_mode(tar),
    .st_atime = th_get_mtime(tar),
    .st_mtime = th_get_mtime(tar),
    .st_ctime = th_get_mtime(tar)
  };
  ext2_ino_t parent = inode;
  char* link = 0;
  if(type == ET_SYMLINK || type == ET_HARDLINK){
    link = strdup(th_get_linkname(tar));
    if(!link){
      myperror("strdup failed");
      goto error;
    }
  }
  if(type == ET_HARDLINK){
    statbuf.st_mode &= ~S_IFMT;
    {
      char* abspath = mkdirlist(link, true); // Making a zero delimited list and an absolut path was so similar, I just put it into the same function
      free(link);
      link = abspath;
    }
    ext2_ino_t target;
    // Check if inode exists
    err = ext2fs_namei_follow(global_fs, EXT2_ROOT_INO, EXT2_ROOT_INO, link, &target);
    if(err && err != EXT2_ET_FILE_NOT_FOUND){
      errno = err;
      myperror("ext2fs_namei_follow failed");
      goto error;
    }else if(err){
      fprintf(stderr, "Warning: inode hardlinked to doesn't exist, creating a symlink instead\n");
      type = ET_SYMLINK;
      statbuf.st_mode |= S_IFLNK;
    }else{
      struct ext2_inode_large full_inode;
      memset(&full_inode, 0, sizeof(full_inode));
      // Read inode to be hardlinked
      err = ext2fs_read_inode_full(global_fs, target, (struct ext2_inode*)&full_inode, sizeof(full_inode));
      if(err){
        errno = err;
        myperror("ext2fs_read_inode_full failed");
        goto error;
      }
      if(LINUX_S_ISDIR(full_inode.i_mode)){
        fprintf(stderr, "Warning: won't create a hardlink to a directory, creating a symlink instead\n");
        type = ET_SYMLINK;
        statbuf.st_mode |= S_IFLNK;
      }else{
        // Check if file already exists
        err = ext2fs_namei(global_fs, EXT2_ROOT_INO, parent, component, &inode);
        if(!err){
          if(inode == target){ // hardlink already exists
            goto end; // Nothing to do
          }else{
            // TODO: replace file with hardlink
            type = ET_SYMLINK;
            statbuf.st_mode |= S_IFLNK;
          }
        }else if(err == EXT2_ET_FILE_NOT_FOUND){
          full_inode.i_links_count += 1; // Increase hardlink count
          // Write inode with new link count
          err = ext2fs_write_inode_full(global_fs, target, (struct ext2_inode*)&full_inode, sizeof(full_inode));
          if(err){
            errno = err;
            myperror("ext2fs_write_inode_full failed");
            goto error;
          }
          // Get file type
          int ext_type = helper_ext_file_type(statbuf.st_mode);
          // Create hardlink
          err = ext2fs_link(global_fs, parent, component, target, ext_type);
          if( err == EXT2_ET_DIR_NO_SPACE ){
            err = ext2fs_expand_dir(global_fs, parent);
            if(!err)
              err = ext2fs_link(global_fs, parent, component, target, ext_type);
          }
          if(err){
            full_inode.i_links_count -= 1; // Try to revert increasing hardlink count
            ext2fs_write_inode_full(global_fs, target, (struct ext2_inode*)&full_inode, sizeof(full_inode));
            errno = err;
            myperror("ext2fs_link failed");
            goto error;
          }
        }else{
          errno = err;
          myperror("ext2fs_namei failed");
          goto error;
        }
      }
    }
  }
  if(type == ET_DIRECTORY){
    // Lookup or create directory
    if(helper_ext_mkdir_follow(parent, component, &inode)){
      myperror("helper_ext_mkdir_follow failed");
      goto error;
    }
    if(helper_ext_stat(inode, &statbuf)){
      perror("helper_ext_stat failed");
      goto error;
    }
  }else if(type == ET_SYMLINK){
    // Check if inode exists
    err = ext2fs_namei(global_fs, EXT2_ROOT_INO, parent, component, &inode);
    if(!err){
      // Change mode and so on
      // TODO: Remove & recreate file instead of erroring out on file type mismatch
      if(helper_ext_stat(inode, &statbuf)){
        perror("helper_ext_stat failed");
        goto error;
      }
      goto end;
    }
    if(err != EXT2_ET_FILE_NOT_FOUND){
      errno = err;
      myperror("ext2fs_namei failed");
      goto error;
    }
    // Create symlink
    err = ext2fs_symlink(global_fs, parent, 0, component, link);
    if(err == EXT2_ET_DIR_NO_SPACE){
      err = ext2fs_expand_dir(global_fs, parent);
      if(!err)
        err = ext2fs_symlink(global_fs, parent, 0, component, link);
    }
    if(err){
      errno = err;
      myperror("ext2fs_symlink failed");
      goto error;
    }
    err = ext2fs_namei(global_fs, EXT2_ROOT_INO, parent, component, &inode);
    if(err){
      errno = err;
      myperror("ext2fs_namei failed");
      goto error;
    }
    if(helper_ext_stat(inode, &statbuf)){
      perror("helper_ext_stat failed");
      goto error;
    }
  }else if( type == ET_REGULAR
         || type == ET_CHARACTER_DEVICE
         || type == ET_BLOCK_DEVICE
         || type == ET_FIFO
  ){
    // Check if inode exists
    err = ext2fs_namei(global_fs, EXT2_ROOT_INO, parent, component, &inode);
    if(!err){
      // Change mode and so on
      // TODO: Remove & recreate file instead of erroring out on file type mismatch
      if(helper_ext_stat(inode, &statbuf)){
        perror("helper_ext_stat failed");
        goto error;
      }
      goto end;
    }
    if(err != EXT2_ET_FILE_NOT_FOUND){
      errno = err;
      myperror("ext2fs_namei failed");
      goto error;
    }
    // Create a new inode
    err = ext2fs_new_inode(global_fs, parent, statbuf.st_mode, 0, &inode);
    if(err){
      errno = err;
      myperror("ext2fs_new_inode failed");
      goto error;
    }
    int ext_type = ((int[]){
      [ET_REGULAR] = EXT2_FT_REG_FILE,
      [ET_SYMLINK] = EXT2_FT_SYMLINK,
      [ET_CHARACTER_DEVICE] = EXT2_FT_CHRDEV,
      [ET_BLOCK_DEVICE] = EXT2_FT_BLKDEV,
      [ET_FIFO] = EXT2_FT_FIFO
    })[type];
    // Add inode to directory
    err = ext2fs_link(global_fs, parent, component, inode, ext_type);
    if( err == EXT2_ET_DIR_NO_SPACE ){
      err = ext2fs_expand_dir(global_fs, parent);
      if(!err)
        err = ext2fs_link(global_fs, parent, component, inode, ext_type);
    }
    if(err){
      errno = err;
      myperror("ext2fs_link failed");
      goto error;
    }
    // Set basic data of inode, like type, uid, gid, mode, and so on
    struct ext2_inode_large full_inode;
    memset(&full_inode, 0, sizeof(full_inode));
    full_inode.i_mode = statbuf.st_mode;
    full_inode.i_links_count = 1;
    full_inode.i_extra_isize = sizeof(struct ext2_inode_large) - EXT2_GOOD_OLD_INODE_SIZE;
    full_inode.i_uid = statbuf.st_uid;
    full_inode.i_gid = statbuf.st_gid;
    if(type == ET_BLOCK_DEVICE || type == ET_CHARACTER_DEVICE){
      full_inode.i_block[0] = th_get_devminor(tar);
      full_inode.i_block[1] = th_get_devmajor(tar);
    }
    full_inode.i_atime = statbuf.st_atime;
    full_inode.i_ctime = statbuf.st_ctime;
    full_inode.i_mtime = statbuf.st_mtime;
    // Write inode
    err = ext2fs_write_new_inode(global_fs, inode, (struct ext2_inode*)&full_inode);
    if(err){
      myperror("ext2fs_write_new_inode failed");
      goto error;
    }
    err = ext2fs_write_inode_full(global_fs, inode, (struct ext2_inode*)&full_inode,  sizeof(full_inode));
    if(err){
      myperror("ext2fs_write_inode_full failed");
      goto error;
    }
    ext2fs_inode_alloc_stats2(global_fs, inode, 1, 0);
  }
end:
  if(link)
    free(link);
  free(list);
  *result = inode;
  return 0;
error:
  if(link)
    free(link);
  free(list);
  return -1;
}

int helper_ext_open(const char* image){
  errcode_t err = 0;
  err = ext2fs_open2(image, 0, EXT2_FLAG_RW | EXT2_FLAG_64BITS | EXT2_FLAG_EXCLUSIVE, 0, 0, unix_io_manager, &global_fs);
  if(err){
    errno = err;
    myperror("ext2fs_open2 failed");
    return -1;
  }
  err = ext2fs_read_inode_bitmap(global_fs);
  if(err){
    errno = err;
    myperror("ext2fs_read_inode_bitmap failed");
    goto error;
  }
  err = ext2fs_read_block_bitmap(global_fs);
  if(err){
    errno = err;
    myperror("ext2fs_read_block_bitmap failed");
    goto error;
  }
  if(global_fs->super->s_state & EXT2_ERROR_FS){
    fprintf(stderr,"Errors detected; running e2fsck is required.\n");
    goto error;
  }
  return 0;
error:
  ext2fs_close(global_fs);
  return -1;
}

int main(int argc, char* argv[]){

  int ret = 0;
  errcode_t err = 0;

  // Check number of arguments
  if(argc != 2){
    printf("Usage: %s image.ext < archive.tar", argv[0]);
    return 1;
  }

  add_error_table(&et_ext2_error_table); // Register ext specific errnos

  if(helper_ext_open(argv[1])){
    myperror("helper_ext_open failed");
    goto error;
  }

  // Get handle for tar from stdin
  ret = tar_fdopen(&tar, STDIN_FILENO, 0, 0, O_RDONLY, 0, 0);
  if(ret){ // This can't fail anyway, but whatever
    myperror("tar_fdopen failed");
    goto error_before_ext_close;
  }

  // For every file
  while(!(ret = th_read(tar))){
    // tar->th_buf.name
    ext2_ino_t inode = 0;
    if(helper_ext_create(&inode))
      goto error_before_tar_close;
    if(TH_ISREG(tar)){ // If it's a regular file
      ext2_file_t efp;
      // open file
      err = ext2fs_file_open(global_fs, inode, O_WRONLY, &efp);
      if(err){
        errno = err;
        myperror("ext2fs_file_open failed");
        goto error;
      }
      // truncate file
      err = ext2fs_file_llseek(efp, 0, SEEK_SET, 0);
      if(err){
        errno = err;
        myperror("ext2fs_file_llseek failed");
        goto error;
      }
      // get the size
      size_t size = th_get_size(tar);
      // Copy the content blockwise
      for(size_t si=size, s=0; si; si -= s){
        s = si>T_BLOCKSIZE ? T_BLOCKSIZE : si; // Get size of actual data in block
        ssize_t rret = tar_block_read(tar, buffer); // Note: The last block isn't truncated to the file size, but a full block
        if(rret != T_BLOCKSIZE){
          if(!errno) errno = EINVAL;
          myperror("tar_block_read failed");
          goto error_before_tar_close;
        }
        unsigned int got = 0;
        // write block
        err = ext2fs_file_write(efp, buffer, s, &got);
        if(err){
          errno = err;
          myperror("ext2fs_file_write failed");
          goto write_error;
        }
        err = ext2fs_file_flush(efp);
        if(err){
          errno = err;
          myperror("ext2fs_file_flush failed");
          goto write_error;
        }
      }
      // close file
      err = ext2fs_file_close(efp);
      if(err){
        errno = err;
        myperror("ext2fs_file_close failed");
        goto error_before_tar_close;
      }
      continue;
      write_error:
        // close file
        err = ext2fs_file_close(efp);
        if(err){
          errno = err;
          myperror("ext2fs_file_close failed");
        }
        goto error_before_tar_close;
    }
  }
  if(ret == -1){
    myperror("th_read failed");
    goto error_before_tar_close;
  }

  // Close ext fs
  ext2fs_close(global_fs);
  // Close tar handle
  tar_close(tar);

  return 0;

// Cleanup after errors
error_before_tar_close:
  tar_close(tar);
error_before_ext_close:
  ext2fs_close(global_fs);
error:
  return 2;
}
