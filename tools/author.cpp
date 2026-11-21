// SPDX-License-Identifier: GPL-3.0-only
// Graffiti Lab adaptation of gBGYo/ReSkate_blood's decal recipe.
// Based on 52b0f130f725ce24cf66fe89ef92b7d69827cd14, modified 2026-11-21.
#include "Engine/Core/Json/json.h"
#include "Engine/Resource/cas_codec.h"
#include "Engine/Resource/ebx_writer.h"
#include "Engine/Resource/texture.h"
#include "Engine/Vfs/game_bundles.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <fstream>
#include <functional>
#include <iostream>
#include <set>

namespace fs = std::filesystem;
namespace fb = dingosdk::frostbite;
namespace ebx = fb::ebx;
using dingosdk::Json;
namespace {

constexpr auto target = "win32/levels/game/dingolevel_root/dingolevel_root";
constexpr std::uint64_t private_material = 0x674c616200ed0019ULL;
template <class T> T get(const std::vector<std::byte> &b, std::size_t p) {
  T v;
  if (p + sizeof(v) > b.size())
    throw std::runtime_error("Truncated material resource");
  std::memcpy(&v, b.data() + p, sizeof(v));
  return v;
}
template <class T> void put(std::vector<std::byte> &b, std::size_t p, T v) {
  if (p + sizeof(v) > b.size())
    throw std::runtime_error("Truncated material resource");
  std::memcpy(b.data() + p, &v, sizeof(v));
}
ebx::Value &field(ebx::Object &o, std::string_view name) {
  for (auto &f : o.fields)
    if (f.name == name)
      return f.value;
  throw std::runtime_error("Missing donor field: " + std::string(name));
}
std::string hex(std::span<const std::byte> b) {
  std::string s;
  for (auto c : b) {
    const auto v = std::to_integer<unsigned>(c);
    s += "0123456789abcdef"[v >> 4];
    s += "0123456789abcdef"[v & 15];
  }
  return s;
}
void write(const fs::path &p, std::span<const std::byte> b) {
  std::ofstream f(p, std::ios::binary);
  f.write(reinterpret_cast<const char *>(b.data()), b.size());
  if (!f)
    throw std::runtime_error("Could not write decal asset");
}
void alias_material(fb::BundleAsset &a, std::vector<std::byte> &raw,
                    std::uint64_t original_material,
                    std::uint64_t private_material) {
  std::vector<std::byte> alias;
  if (a.resourceType == 0xe2e6955b) {
    const auto start = get<std::uint32_t>(a.resourceMeta, 0) +
                       get<std::uint32_t>(a.resourceMeta, 4);
    const auto n = get<std::uint32_t>(raw, start);
    std::size_t p = start + 4;
    for (unsigned row = 0; row < n; ++row) {
      const auto length = 12 + std::size_t(get<std::uint32_t>(raw, p + 8)) * 4;
      if (p > raw.size() || length > raw.size() - p)
        throw std::runtime_error("Invalid shader program row");
      if (get<std::uint64_t>(raw, p) == original_material)
        alias.assign(raw.begin() + p, raw.begin() + p + length);
      p += length;
    }
    if (p != raw.size() || alias.empty())
      throw std::runtime_error("Missing donor compiled program");
    put(alias, 0, private_material);
    p = start + 4;
    for (unsigned row = 0;
         row < n && get<std::uint64_t>(raw, p) < private_material; ++row)
      p += 12 + std::size_t(get<std::uint32_t>(raw, p + 8)) * 4;
    raw.insert(raw.begin() + p, alias.begin(), alias.end());
    put(raw, start, n + 1);
    put(a.resourceMeta, 8,
        get<std::uint32_t>(a.resourceMeta, 8) + std::uint32_t(alias.size()));
  } else {
    for (std::size_t p = 0; p + 16 <= raw.size(); p += 16)
      if (get<std::uint64_t>(raw, p) == original_material) {
        alias.assign(raw.begin() + p, raw.begin() + p + 16);
        break;
      }
    if (alias.empty())
      throw std::runtime_error("Missing donor texture lookup");
    put(alias, 0, private_material);
    std::size_t p{};
    while (p < raw.size() && get<std::uint64_t>(raw, p) < private_material)
      p += 16;
    raw.insert(raw.begin() + p, alias.begin(), alias.end());
  }
}

fb::Guid ground_guid(unsigned slot) {
  // A project-specific SplitMix64 seed keeps all private EBX and chunk IDs
  // stable.
  std::uint64_t state = 0x638e74cba2ddfe01ULL + slot;
  fb::Guid id;
  for (unsigned half = 0; half < 2; ++half) {
    auto n = (state += 0x9e3779b97f4a7c15ULL);
    n = (n ^ (n >> 30)) * 0xbf58476d1ce4e5b9ULL;
    n = (n ^ (n >> 27)) * 0x94d049bb133111ebULL;
    n ^= n >> 31;
    for (unsigned b = 0; b < 8; ++b)
      id.bytes[half * 8 + b] = std::byte(n >> (b * 8));
  }
  return id;
}
ebx::InstanceRecord &ground_instance(ebx::Document &doc) {
  if (!doc.root())
    throw std::runtime_error("Missing donor EBX root");
  return doc.instances.at(doc.root() - doc.instances.data());
}
fb::Image read_image(const fs::path &file) {
  constexpr unsigned side = 512;
  fb::Image image{side, side, std::vector<std::uint8_t>(side * side * 4)};
  std::ifstream in(file, std::ios::binary);
  if (!in.read(reinterpret_cast<char *>(image.rgba.data()),
               image.rgba.size()) ||
      in.peek() != std::ifstream::traits_type::eof())
    throw std::runtime_error("Expected exactly 512 x 512 RGBA pixels");
  return image;
}
template <class Emit>
void author_decal(dingosdk::vfs::GameData &data, const fs::path &textures,
                  const std::string &id, unsigned slot, Emit &output) {
  constexpr auto donor = "win32/levels/game/bam_levelroot/wproot/wp/s9600_x0z0/"
                         "s200_x500z1100/s100_x450z1150/s50_x425z1175_sublevel";
  constexpr auto stem = "world/materials/decal/graffiti_large_01_4x2m/"
                        "decal_graffiti_large_01_4x2m";

  const auto toc =
      data.read_toc("Win32/levels/game/bam_levelroot/bam_levelroot.toc");
  const auto bundle = data.read_bundle(toc, donor);
  if (!bundle)
    throw std::runtime_error("Missing surface decal donor bundle");
  auto emit = [&](fb::AssetKind kind, fb::BundleAsset a,
                  const std::vector<std::byte> &bytes) {
    if (kind == fb::AssetKind::resource && !(a.resourceId & 1))
      throw std::runtime_error("Decal resource IDs must be odd");
    output(kind, a, bytes, true);
  };
  auto read = [&](fb::AssetKind kind, const std::string &name,
                  fb::BundleAsset &a) {
    std::size_t index{};
    const auto *found = bundle->find(kind, name, &index);
    if (!found)
      throw std::runtime_error("Missing decal material donor: " + name);
    a = *found;
    return data.read(*bundle->payload(kind, index));
  };
  const auto image = read_image(textures);
  const unsigned offset = slot * 0x100;
  const auto guid = [offset](unsigned index) { return ground_guid(offset + index); };
  const std::string output_stem = "world/materials/decal/reskate_graffitilab/" + id;
  const auto color_file = guid(0x10), color_class = guid(0x11);
  const auto normal_file = guid(0x20), normal_class = guid(0x21);
  const auto opacity_file = guid(0x30), opacity_class = guid(0x31);
  const auto material_key = private_material + offset;
  struct Binding {
    fb::Guid old_file, old_class, new_file, new_class;
  };
  std::vector<Binding> bindings;
  for (const unsigned kind : {0u, 1u, 2u}) {
    const bool normal = kind == 1, opacity = kind == 2;
    const std::string suffix = normal ? "_ny" : opacity ? "_osm" : "_c";
    fb::BundleAsset ebx_asset, res_asset;
    auto doc = ebx::read_document(
        read(fb::AssetKind::ebx, std::string(stem) + suffix, ebx_asset));
    auto &instance = ground_instance(doc);
    const auto file = normal    ? normal_file
                      : opacity ? opacity_file
                                : color_file,
               klass = normal    ? normal_class
                       : opacity ? opacity_class
                                 : color_class;
    bindings.push_back({doc.fileGuid, instance.instanceGuid, file, klass});
    doc.fileGuid = file;
    instance.instanceGuid = klass;
    const auto name = output_stem + suffix;
    field(*instance.object, "Name").data = name;
    const std::uint64_t rid = offset + (normal    ? 0x674c616200ed0023ULL
                              : opacity ? 0x674c616200ed0025ULL
                                        : 0x674c616200ed0021ULL);
    field(*instance.object, "Resource").data = ebx::ResourceReference{rid};
    const std::uint32_t width = normal ? 4 : image.width,
                        height = normal ? 4 : image.height;
    field(*instance.object, "AuthoredWidth").data = std::uint64_t(width);
    field(*instance.object, "AuthoredHeight").data = std::uint64_t(height);
    auto crop = std::get<std::shared_ptr<ebx::Object>>(
        field(*instance.object, "CropInfo").data);
    field(*crop, "Z").data = double(width);
    field(*crop, "W").data = double(height);
    const auto authored_ebx = ebx::write_document(doc);
    const auto checked_ebx = ebx::read_document(authored_ebx);
    if (checked_ebx.fileGuid != file ||
        checked_ebx.root()->instanceGuid != klass ||
        std::get<ebx::ResourceReference>(
            checked_ebx.root()->object->find("Resource")->value.data)
                .id != rid)
      throw std::runtime_error("Texture EBX round-trip failed");
    ebx_asset.name = name;
    emit(fb::AssetKind::ebx, ebx_asset, authored_ebx);
    auto texture =
        read(fb::AssetKind::resource, std::string(stem) + suffix, res_asset);
    if (texture.size() != 180 ||
        get<std::uint32_t>(res_asset.resourceMeta, 0) != 12)
      throw std::runtime_error("Unexpected texture format");
    const auto chunk = normal ? guid(0x22) : opacity ? guid(0x32) : guid(0x12);
    put(texture, 12,
        std::uint32_t(
            normal || opacity ? 18 : 20)); // Linear packed data / sRGB color.
    // Retain the donor's native usage flags. Streaming residency is carried
    // separately in RES metadata and the authored mip data.
    put(texture, 20, std::uint16_t(1));
    put(res_asset.resourceMeta, 4, std::uint32_t(0));
    put(texture, 22, std::uint16_t(width));
    put(texture, 24, std::uint16_t(height));
    put(texture, 31, std::uint8_t(0));
    std::copy(chunk.bytes.begin(), chunk.bytes.end(), texture.begin() + 40);
    std::fill(texture.begin() + 56, texture.begin() + 116, std::byte{});
    fb::Image mip = image;
    if (normal) {
      mip = {4, 4, std::vector<std::uint8_t>(64)};
      for (std::size_t p = 0; p < 64; p += 4) {
        mip.rgba[p] = 128;
        mip.rgba[p + 1] = 128;
        mip.rgba[p + 2] = 255;
        mip.rgba[p + 3] = 255;
      }
    }
    // The stock OSM's red channel is the graffiti opacity mask. Color alpha
    // alone does not supply it. Preserve the verified donor finish and flat
    // normal until its full normal/specular packing is established. Generic lab
    // normal and roughness PNGs are deliberately not treated as native packed
    // maps.
    if (opacity)
      for (std::size_t p = 0; p < mip.rgba.size(); p += 4) {
        mip.rgba[p] = image.rgba[p + 3];
        mip.rgba[p + 1] = 185;
        mip.rgba[p + 2] = 0;
        mip.rgba[p + 3] = 255;
      }
    const auto expected_image = mip;
    std::vector<std::byte> pixels;
    std::uint8_t count{};
    for (;;) {
      put(texture, 56 + 4 * count, std::uint32_t(mip.rgba.size()));
      ++count;
      const auto b = std::as_bytes(std::span(mip.rgba));
      pixels.insert(pixels.end(), b.begin(), b.end());
      if (mip.width == 1 && mip.height == 1)
        break;
      mip = fb::resize(mip, std::max(1u, mip.width / 2),
                       std::max(1u, mip.height / 2));
    }
    put(texture, 30, count);
    put(texture, 116, std::uint32_t(pixels.size()));
    put(texture, 120, rid);
    // Texture's first two words and streaming layout describe old mip slices.
    put(texture, 0, std::uint32_t(0));
    put(texture, 4, std::uint32_t(0));
    put(texture, 32, std::uint32_t(0));
    put(texture, 36, std::uint32_t(0));
    const auto header =
        fb::read_texture_header(texture, res_asset.resourceMeta);
    const auto decoded =
        fb::decode_texture(header, pixels, std::min(width, height));
    if (decoded.width != width || decoded.height != height ||
        decoded.rgba != expected_image.rgba)
      throw std::runtime_error("Texture round-trip failed");
    res_asset.name = name;
    res_asset.resourceId = rid;
    emit(fb::AssetKind::resource, res_asset, texture);
    fb::BundleAsset ca;
    ca.name = chunk.string();
    ca.guid = chunk;
    emit(fb::AssetKind::chunk, ca, pixels);
  }
  fb::BundleAsset decal_asset;
  auto decal = ebx::read_document(
      read(fb::AssetKind::ebx, std::string(stem) + "_dv", decal_asset));
  decal.fileGuid = guid(0x40);
  auto &instance = ground_instance(decal);
  instance.instanceGuid = guid(0x41);
  field(*instance.object, "Name").data = std::string(output_stem) + "_dv";
  field(*instance.object, "ShaderInstanceKey").data =
      std::int64_t(material_key);
  const auto authored_decal = ebx::write_document(decal);
  const auto checked_decal = ebx::read_document(authored_decal);
  if (checked_decal.fileGuid != decal.fileGuid ||
      checked_decal.root()->instanceGuid != instance.instanceGuid ||
      std::get<std::int64_t>(checked_decal.root()
                                 ->object->find("ShaderInstanceKey")
                                 ->value.data) != std::int64_t(material_key))
    throw std::runtime_error("Decal EBX round-trip failed");
  decal_asset.name = std::string(output_stem) + "_dv";
  emit(fb::AssetKind::ebx, decal_asset, authored_decal);
  const auto depot_it = std::find_if(
      bundle->manifest.resources.begin(), bundle->manifest.resources.end(),
      [](const auto &a) { return a.resourceId == 2515853284392278695ULL; });
  if (depot_it == bundle->manifest.resources.end())
    throw std::runtime_error("Missing shader depot");
  auto depot_asset = *depot_it;
  auto depot = data.read(*bundle->payload(
      fb::AssetKind::resource, depot_it - bundle->manifest.resources.begin()));
  const auto table = get<std::uint64_t>(depot, 0);
  const auto count = get<std::uint32_t>(depot_asset.resourceMeta, 12);
  std::uint64_t block{};
  for (std::uint32_t i = 0; i < count; ++i)
    if (get<std::uint64_t>(depot, table + 16 * i) == 0x9b3233728e841bc0ULL)
      block = get<std::uint64_t>(depot, table + 16 * i + 8);
  if (!block)
    throw std::runtime_error("Missing textured shader entry");
  // Publish one new material key. Retain internal offsets and relocation data;
  // the other donor entries are inaccessible from this private depot.
  put(depot, table, material_key);
  put(depot, table + 8, block);
  put(depot_asset.resourceMeta, 12, std::uint32_t(1));
  const auto params = get<std::uint64_t>(depot, block);
  const auto params_size = get<std::uint32_t>(depot, block + 16);
  if (params + params_size > depot.size())
    throw std::runtime_error("Invalid persistent parameter block");
  for (const auto &binding : bindings) {
    std::array<std::byte, 32> old{}, replacement{};
    std::copy(binding.old_class.bytes.begin(), binding.old_class.bytes.end(),
              old.begin());
    std::copy(binding.old_file.bytes.begin(), binding.old_file.bytes.end(),
              old.begin() + 16);
    std::copy(binding.new_class.bytes.begin(), binding.new_class.bytes.end(),
              replacement.begin());
    std::copy(binding.new_file.bytes.begin(), binding.new_file.bytes.end(),
              replacement.begin() + 16);
    const auto end = depot.begin() + params + params_size;
    auto pos = std::search(depot.begin() + params, end, old.begin(), old.end());
    if (pos == end)
      throw std::runtime_error(
          "Texture binding missing from selected material");
    std::copy(replacement.begin(), replacement.end(), pos);
  }
  // Restore white tint in the selected persistent parameter block.
  for (std::size_t p = params; p + 32 <= params + params_size; ++p)
    if (get<std::uint64_t>(depot, p) == 0x8c46cd354b18a9e2ULL &&
        get<std::uint32_t>(depot, p + 8) == 0x885eff59) {
      if (get<float>(depot, p + 20) != .5f ||
          get<float>(depot, p + 24) != .5f || get<float>(depot, p + 28) != .5f)
        throw std::runtime_error("Unexpected tint layout");
      put(depot, p + 20, 1.f);
      put(depot, p + 24, 1.f);
      put(depot, p + 28, 1.f);
    }
  // The engine caches parsed scopes globally by this hash. Modified texture
  // bindings must not reuse the donor's cache identity.
  std::uint64_t params_hash = 14695981039346656037ULL;
  for (std::size_t p = params; p < params + params_size; ++p)
    params_hash = (params_hash ^ std::to_integer<unsigned char>(depot[p])) *
                  1099511628211ULL;
  if (params_hash == get<std::uint64_t>(depot, block + 8))
    throw std::runtime_error("Parameter cache identity did not change");
  put(depot, block + 8, params_hash);
  depot_asset.name =
      "world/materials/decal/reskate_graffitilab/shaderblockdepot_" + id;
  depot_asset.resourceId = 0x674c616200ed0029ULL + offset;
  emit(fb::AssetKind::resource, depot_asset, depot);
}

#include "spray_can.h"
} // namespace
int main(int argc, char **argv) {
  try {
    if (argc < 7 || (argc - 4) % 3 != 0)
      throw std::runtime_error(
          "usage: decal-author GAME EMPTY_OUTPUT CAN_PATCH SLOT ID IMAGE.rgba [SLOT ID IMAGE.rgba ...]");
    const fs::path out = argv[2];
    if (!fs::is_directory(out) || !fs::is_empty(out))
      throw std::runtime_error("Expected an empty output directory");
    dingosdk::vfs::GameData data(argv[1]);
    Json rows = Json::array();
    std::set<std::pair<fb::AssetKind, std::string>> emitted;
    auto emit = [&](fb::AssetKind kind, fb::BundleAsset a,
                    const std::vector<std::byte> &raw, bool added = false) {
      if (!emitted
               .emplace(kind,
                        kind == fb::AssetKind::chunk ? a.guid.string() : a.name)
               .second)
        throw std::runtime_error("Duplicate authored asset: " + a.name);
      const auto file = std::to_string(rows.size()) + ".cas";
      const auto encoded = fb::encode_cas(raw, {argv[1]});
      if (fb::decode_cas(encoded, {argv[1]}) != raw)
        throw std::runtime_error("Decal CAS round-trip failed");
      write(out / file, encoded);
      rows.push_back(Json{
          {"kind", kind == fb::AssetKind::ebx        ? 1
                   : kind == fb::AssetKind::resource ? 2
                                                     : 3},
          {"name", kind == fb::AssetKind::chunk ? a.guid.string() : a.name},
          {"file", file},
          {"size", raw.size()},
          {"type", a.resourceType},
          {"rid", a.resourceId},
          {"meta", hex(a.resourceMeta)},
          {"logical_offset", a.logicalOffset},
          {"logical_size",
           kind == fb::AssetKind::chunk ? raw.size() : a.logicalSize},
          {"target", target},
          {"added", added}});
      if (kind == fb::AssetKind::ebx) {
        const auto document = ebx::read_document(raw);
        rows[rows.size() - 1]["root_type"] = document.rootType;
      }
    };

    CanAssets can(argv[1], argv[3]);
    can.emit_mesh(emit);
    std::set<unsigned> slots;
    for (int i = 4; i < argc; i += 3) {
      const auto slot = std::stoul(argv[i]);
      const std::string id = argv[i + 1];
      if (slot > 127 || !slots.insert(static_cast<unsigned>(slot)).second ||
          id.empty() || id.find_first_not_of("abcdefghijklmnopqrstuvwxyz0123456789_") != std::string::npos)
        throw std::runtime_error("Invalid artwork ID or duplicate slot");
      author_decal(data, argv[i + 2], id, static_cast<unsigned>(slot), emit);
    }
    can.lookups([&](fb::BundleAsset a, std::vector<std::byte> raw) {
      for (const unsigned slot : slots)
        alias_material(a, raw, 0x9b3233728e841bc0ULL, private_material + slot * 0x100);
      emit(fb::AssetKind::resource, a, raw);
    });

    std::ofstream(out / "resources.json") << Json{{"resources", rows}}.dump(2);
    std::cout << "Authored " << slots.size() << " decals and both shared lookup tables ("
              << rows.size() << " payloads).\n";
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
