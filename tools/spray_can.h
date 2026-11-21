// SPDX-License-Identifier: GPL-3.0-only
// Read only the can's render assets from Studio's private, single-prop staging scene.
class CanAssets {
  fs::path game_, patch_;
  dingosdk::vfs::GameArchives archives_;

  dingosdk::vfs::GameBundle bundle(const std::string &name) {
    const auto path = patch_ / (name + ".toc");
    std::vector<std::byte> bytes(fs::file_size(path));
    if (!std::ifstream(path, std::ios::binary).read(reinterpret_cast<char*>(bytes.data()), bytes.size()))
      throw std::runtime_error("Could not read can staging TOC");
    for (const auto &entry : fb::read_toc(bytes).bundles) {
      if (entry.name != name) continue;
      auto region = fb::read_bundle_region(entry.region);
      auto files = std::move(region.files);
      const auto first = files.at(0);
      auto manifest = archives_.read_manifest(patch_, first.location, first.offset, first.size, game_);
      return {std::move(manifest), {files.begin()+1, files.end()}};
    }
    throw std::runtime_error("Missing can staging bundle: " + name);
  }

  std::vector<std::byte> read(const fb::BundleFileInfo &file) {
    if (!file.location.patch) throw std::runtime_error("Expected a Studio-authored can asset");
    return fb::decode_cas(archives_.read(patch_,file.location,file.offset,file.size), {game_});
  }

public:
  CanAssets(const fs::path &game, const fs::path &patch)
      : game_(game), patch_(patch), archives_(patch, dingosdk::vfs::read_layout(patch/"layout.toc").root) {}

  template<class Emit> void emit_mesh(Emit &emit) {
    const auto scene = bundle("win32/levels/game/dingolevel_reskate_graffitilab_can/dingolevel_reskate_graffitilab_can");
    unsigned meshes{}, props{}, textures{}, depots{}, variations{};
    for (auto kind : {fb::AssetKind::ebx,fb::AssetKind::resource,fb::AssetKind::chunk}) {
      const auto &items = kind == fb::AssetKind::ebx ? scene.manifest.ebx :
          kind == fb::AssetKind::resource ? scene.manifest.resources : scene.manifest.chunks;
      for (std::size_t i=0; i<items.size(); ++i) {
        const auto &asset = items[i];
        const auto &file = *scene.payload(kind,i);
        if (!file.location.patch) continue;
        if (kind == fb::AssetKind::ebx || kind == fb::AssetKind::resource) {
          if (!asset.name.starts_with("world/custom/dingolevel_reskate_graffitilab_can/") &&
              !asset.name.ends_with("/meshvariationdb_win32") && asset.resourceType != 0x73312045) continue;
        }
        auto bytes = read(file);
        if (kind == fb::AssetKind::ebx) {
          auto type = ebx::read_document(bytes).rootType;
          meshes += type=="RigidMeshAsset"; props += type=="ObjectBlueprint";
          textures += type=="TextureAsset"; variations += type=="MeshVariationDatabase";
        }
        depots += kind==fb::AssetKind::resource && asset.resourceType==0x73312045;
        emit(kind,asset,bytes,true);
      }
    }
    if (meshes!=1 || props!=1 || textures!=3 || variations!=1 || depots!=1)
      throw std::runtime_error("Expected one portable can mesh with its three textures and material");
  }

  // Studio already registered the can's material keys against this exact stock
  // build. Extend these same two tables with the decal aliases in author.cpp.
  void lookups(std::function<void(fb::BundleAsset,std::vector<std::byte>)> emit) {
    const auto root=bundle(target);
    unsigned count{};
    for(std::size_t i=0;i<root.manifest.resources.size();++i) {
      const auto &a=root.manifest.resources[i];
      if(a.resourceType!=0xe2e6955b && a.resourceType!=0x2d254a89) continue;
      emit(a,read(*root.payload(fb::AssetKind::resource,i))); ++count;
    }
    if(count!=2) throw std::runtime_error("Can shader lookup tables missing");
  }
};
